import Foundation
import UIKit
import Combine
import FirebaseFirestore

/// Items 2, 9, 14: one shared AI list per Needs Me account, the same on phone, web, Android, Mac and Windows.
/// Firestore users/{uid}/settings/aiaccounts = { json: "{v:1,accounts:[...]}", updated: ms, device }.
/// Each account: id, ai, aiName, url, name, desc, emoji, img, color, nf{done,needs,msgs}, use{chats,needs,updates}, at, del.
/// The newer `at` wins. `del: true` means removed (kept so a removal here removes it everywhere).
/// AI logins (cookies, passwords) are never shared: each device signs in to each AI once.
@MainActor
final class SharedSync {
    static let shared = SharedSync()
    private var handle: ListenerRegistration?
    private var uid: String?
    private var remote: [String: [String: Any]] = [:]
    private var bag = Set<AnyCancellable>()
    private var applying = false
    private let ud = UserDefaults.standard

    private var known: Set<String> {
        get { Set(ud.stringArray(forKey: "nm_shared_known") ?? []) }
        set { ud.set(Array(newValue), forKey: "nm_shared_known") }
    }
    private var pendingDel: Set<String> {
        get { Set(ud.stringArray(forKey: "nm_shared_pdel") ?? []) }
        set { ud.set(Array(newValue), forKey: "nm_shared_pdel") }
    }
    private var atMap: [String: Double] {
        get { (ud.dictionary(forKey: "nm_shared_at") as? [String: Double]) ?? [:] }
        set { ud.set(newValue, forKey: "nm_shared_at") }
    }
    private var sigMap: [String: String] {
        get { (ud.dictionary(forKey: "nm_shared_sig") as? [String: String]) ?? [:] }
        set { ud.set(newValue, forKey: "nm_shared_sig") }
    }

    func start(uid: String) {
        if self.uid == uid, handle != nil { return }
        stop()
        self.uid = uid
        handle = Firestore.firestore().collection("users").document(uid).collection("settings").document("aiaccounts")
            .addSnapshotListener { [weak self] snap, _ in
                let json = snap?.data()?["json"] as? String ?? ""
                let exists = snap?.exists ?? false
                Task { @MainActor in self?.onRemote(json: json, exists: exists) }
            }
        let ping: () -> Void = { [weak self] in Task { @MainActor in self?.push() } }
        AIConnections.shared.objectWillChange.debounce(for: .seconds(2), scheduler: DispatchQueue.main).sink { _ in ping() }.store(in: &bag)
        AvatarStore.shared.objectWillChange.debounce(for: .seconds(2), scheduler: DispatchQueue.main).sink { _ in ping() }.store(in: &bag)
        AlertPrefs.shared.objectWillChange.debounce(for: .seconds(2), scheduler: DispatchQueue.main).sink { _ in ping() }.store(in: &bag)
    }

    func stop() {
        handle?.remove(); handle = nil; uid = nil; remote = [:]; bag.removeAll()
    }

    /// She removed this account on this phone: tell every other device.
    func removed(_ id: String) {
        guard !applying else { return }
        var p = pendingDel; p.insert(id); pendingDel = p
        var k = known; k.remove(id); known = k
        push()
    }

    // MARK: remote -> phone

    private func parse(_ json: String) -> [[String: Any]] {
        guard let d = json.data(using: .utf8), let o = try? JSONSerialization.jsonObject(with: d) else { return [] }
        if let a = o as? [[String: Any]] { return a }
        return (o as? [String: Any])?["accounts"] as? [[String: Any]] ?? []
    }
    private func num(_ v: Any?) -> Double {
        if let d = v as? Double { return d }
        if let i = v as? Int { return Double(i) }
        if let s = v as? String, let d = Double(s) { return d }
        return 0
    }
    private func flag(_ d: Any?, _ k: String, _ def: Bool) -> Bool { (d as? [String: Any])?[k] as? Bool ?? def }

    private func onRemote(json: String, exists: Bool) {
        var m: [String: [String: Any]] = [:]
        for r in parse(json) { if let id = r["id"] as? String, !id.isEmpty { m[id] = r } }
        remote = m
        apply()
        push()
    }

    private func apply() {
        applying = true
        defer { applying = false }
        let conns = AIConnections.shared, av = AvatarStore.shared
        var at = atMap, k = known, sigs = sigMap
        for (id, r) in remote {
            let rat = num(r["at"])
            if rat <= (at[id] ?? 0) { continue }
            if (r["del"] as? Bool) == true {
                if let a = conns.account(id) { conns.removeShared(a) }
                av.clear(id); k.remove(id); sigs[id] = nil; at[id] = rat
                continue
            }
            let ai = (r["ai"] as? String) ?? "custom"
            let provider = webAI(ai) != nil ? ai : "custom"
            let aiName = (r["aiName"] as? String) ?? ""
            var label = (r["name"] as? String) ?? ""
            if label.isEmpty || label == "Main" { label = aiName.isEmpty ? (webAI(provider)?.name ?? "AI") : aiName }
            var url = (r["url"] as? String) ?? ""
            if url.isEmpty { url = webAI(provider)?.url ?? "" }
            if conns.account(id) == nil {
                conns.adoptShared(AIAccount(id: id, provider: provider, label: label, url: provider == "custom" ? url : nil))
            } else if let a = conns.account(id), a.label != label { conns.rename(a, to: label) }
            OpenTabs.shared.markSeen(id)
            if let c = r["color"] as? String, c.hasPrefix("#"), let h = Int(c.dropFirst(), radix: 16) { av.setColorHex(h, id) } else { av.setColorHex(nil, id) }
            if let e = r["emoji"] as? String, !e.isEmpty { av.setEmoji(e, id) }
            av.setDesc((r["desc"] as? String) ?? "", id)
            if let s = r["img"] as? String, s.hasPrefix("data:image"), let comma = s.firstIndex(of: ","),
               let d = Data(base64Encoded: String(s[s.index(after: comma)...])), let img = UIImage(data: d) { av.setImage(img, id) }
            AlertPrefs.shared.importFlags(id, done: flag(r["nf"], "done", true), needs: flag(r["nf"], "needs", true), msgs: flag(r["nf"], "msgs", true),
                                        chats: flag(r["use"], "chats", true), uneeds: flag(r["use"], "needs", true), updates: flag(r["use"], "updates", true))
            k.insert(id); at[id] = rat
            if let a = conns.account(id) { sigs[id] = sig(a) }
        }
        atMap = at; known = k; sigMap = sigs
    }

    // MARK: phone -> remote

    private func hex(_ h: Int) -> String { String(format: "#%06X", h & 0xFFFFFF) }
    private func sig(_ a: AIAccount) -> String {
        let av = AvatarStore.shared, p = AlertPrefs.shared
        return [a.label, a.url ?? "", av.colorHex(a.id).map { hex($0) } ?? "", av.emoji(a.id) ?? "", av.desc(a.id),
                "\(av.imageStamp(a.id))", p.on(a.id, "done") ? "1" : "0", p.on(a.id, "needs") ? "1" : "0", p.on(a.id, "msgs") ? "1" : "0", p.on(a.id, "uchats") ? "1" : "0", p.on(a.id, "uneeds") ? "1" : "0", p.on(a.id, "uupdates") ? "1" : "0"].joined(separator: "|")
    }
    private func imgData(_ id: String) -> String {
        guard let img = AvatarStore.shared.image(id) else { return "" }
        let side: CGFloat = 96
        let small = UIGraphicsImageRenderer(size: CGSize(width: side, height: side)).image { _ in img.draw(in: CGRect(x: 0, y: 0, width: side, height: side)) }
        guard let d = small.jpegData(compressionQuality: 0.5) else { return "" }
        let s = "data:image/jpeg;base64," + d.base64EncodedString()
        return s.count <= 60000 ? s : ""
    }

    private func push() {
        guard let uid, !applying else { return }
        let conns = AIConnections.shared, av = AvatarStore.shared, p = AlertPrefs.shared
        var at = atMap, sigs = sigMap, k = known, pd = pendingDel
        let now = (Date().timeIntervalSince1970 * 1000).rounded()
        var out = remote
        // accounts this phone has logged in to on the web, plus ones brought in from other devices
        for a in conns.accounts {
            let isWeb = AIKeys.load(a.id) == "web"
            guard isWeb || k.contains(a.id) else { continue }
            if pd.contains(a.id) && !isWeb { continue }
            pd.remove(a.id)
            let s = sig(a)
            if sigs[a.id] != s || at[a.id] == nil { at[a.id] = now; sigs[a.id] = s }
            let mine = at[a.id] ?? now
            if let r = out[a.id], num(r["at"]) >= mine, (r["del"] as? Bool) != true { continue }
            let shownName = a.label == a.platformName ? "" : a.label
            out[a.id] = [
                "id": a.id, "ai": a.provider, "aiName": a.platformName, "url": a.url ?? webAI(a.provider)?.url ?? "",
                "name": shownName, "desc": String(av.desc(a.id).prefix(300)), "emoji": av.emoji(a.id) ?? "", "img": imgData(a.id),
                "color": av.colorHex(a.id).map { hex($0) } ?? "",
                "nf": ["done": p.on(a.id, "done"), "needs": p.on(a.id, "needs"), "msgs": p.on(a.id, "msgs")],
                "use": ["chats": p.on(a.id, "uchats"), "needs": p.on(a.id, "uneeds"), "updates": p.on(a.id, "uupdates")],
                "at": mine, "del": false,
            ]
            k.insert(a.id)
        }
        for id in pd {
            let base = out[id] ?? ["id": id, "ai": "custom", "aiName": "AI"]
            if num(base["at"]) >= now { continue }
            var d = base; d["at"] = now; d["del"] = true; out[id] = d; at[id] = now
        }
        pendingDel = pd.filter { out[$0] == nil || (out[$0]?["del"] as? Bool) != true }
        atMap = at; sigMap = sigs; known = k
        // write only when something differs from what the server already has
        func key(_ m: [String: [String: Any]]) -> String { m.keys.sorted().map { "\($0)|\(num(m[$0]?["at"]))|\((m[$0]?["del"] as? Bool) == true ? 1 : 0)" }.joined(separator: ",") }
        if key(out) == key(remote) && !remote.isEmpty { return }
        if out.isEmpty { return }
        let list = out.values.sorted { ($0["id"] as? String ?? "") < ($1["id"] as? String ?? "") }
        guard let d = try? JSONSerialization.data(withJSONObject: ["v": 1, "accounts": list]), let s = String(data: d, encoding: .utf8) else { return }
        remote = out
        Firestore.firestore().collection("users").document(uid).collection("settings").document("aiaccounts")
            .setData(["json": s, "updated": Int(now), "device": "iPhone"], merge: true)
    }
}
