import SwiftUI
import FirebaseAuth

/// An AI joined by prompt: no key. It is "Connected" once it makes its first call to the user's link.
struct LinkAI: Codable, Identifiable {
    var id: String       // token id from the bridge
    var key: String      // tile key, for example "claude"
    var label: String
    var seen: Bool = false
}

@MainActor final class LinkStore: ObservableObject {
    static let shared = LinkStore()
    @Published var links: [LinkAI] = []
    private let k = "nm_link_ais"
    init() { if let d = UserDefaults.standard.data(forKey: k), let a = try? JSONDecoder().decode([LinkAI].self, from: d) { links = a } }
    private func save() { if let d = try? JSONEncoder().encode(links) { UserDefaults.standard.set(d, forKey: k) } }
    func token(_ l: LinkAI) -> String? { AIKeys.load("link-" + l.id) }
    var pending: Int { links.filter { !$0.seen }.count }
    func connectedCount(_ key: String) -> Int { links.filter { $0.key == key && $0.seen }.count }

    func make(key: String, label: String) async -> String? {
        guard let u = Auth.auth().currentUser, let idt = try? await u.getIDToken(), let url = URL(string: BridgeCard.base + "/tokens") else { return "Sign in first." }
        var r = URLRequest(url: url); r.httpMethod = "POST"; r.timeoutInterval = 30
        r.setValue("Bearer " + idt, forHTTPHeaderField: "Authorization"); r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        r.httpBody = try? JSONSerialization.data(withJSONObject: ["name": label])
        guard let (d, resp) = try? await URLSession.shared.data(for: r), (resp as? HTTPURLResponse)?.statusCode == 200,
              let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any], let t = j["token"] as? String, let id = j["id"] as? String else { return "Could not make the prompt. Try again." }
        _ = AIKeys.save(t, account: "link-" + id)
        if BridgeSync.shared.token == nil { BridgeSync.shared.saveToken(t) }
        links.append(LinkAI(id: id, key: key, label: label)); save()
        return nil
    }
    func remove(_ l: LinkAI) async {
        if let u = Auth.auth().currentUser, let idt = try? await u.getIDToken(), let url = URL(string: BridgeCard.base + "/tokens/" + l.id) {
            var r = URLRequest(url: url); r.httpMethod = "DELETE"; r.timeoutInterval = 30
            r.setValue("Bearer " + idt, forHTTPHeaderField: "Authorization")
            _ = try? await URLSession.shared.data(for: r)
        }
        AIKeys.remove("link-" + l.id); links.removeAll { $0.id == l.id }; save()
    }
    /// Asks the bridge which links have been used yet.
    func refresh() async {
        guard !links.isEmpty, let u = Auth.auth().currentUser, let idt = try? await u.getIDToken(), let url = URL(string: BridgeCard.base + "/tokens") else { return }
        var r = URLRequest(url: url); r.timeoutInterval = 20
        r.setValue("Bearer " + idt, forHTTPHeaderField: "Authorization")
        guard let (d, resp) = try? await URLSession.shared.data(for: r), (resp as? HTTPURLResponse)?.statusCode == 200,
              let arr = try? JSONSerialization.jsonObject(with: d) as? [[String: Any]] else { return }
        var changed = false
        for x in arr {
            guard let id = x["id"] as? String, let seen = x["seen"] as? Double, seen > 0, let i = links.firstIndex(where: { $0.id == id }), !links[i].seen else { continue }
            links[i].seen = true; changed = true
        }
        if changed { save() }
    }
}

enum LinkPrompt {
    static func text(name: String, token: String) -> String {
        """
        Join my NeedsMe as "\(name)". It is my own private link. Add it as an MCP server (custom connector) with:
        URL: \(BridgeCard.base)/mcp
        Header: Authorization: Bearer \(token)
        Then:
        1. Call get_my_projects and use my exact project names.
        2. After every reply where something changed, call report_update (project, summary, todos_new, todos_done, needs_you, finished, chat_url = the web link to this chat). Use needs_you only when you cannot go on without my answer.
        3. At the start of every reply call check_inbox. If something is addressed to you, answer it with post_message (use the room named in the message) and write @name to bring in another AI. If you can keep running, call wait_for_message again and again so you answer the moment someone @mentions you.
        4. Never share this token. If you cannot add MCP servers, say so, and I will send you the paste-block rule instead.
        """
    }
}

/// The easy way in: make a prompt, copy it, open the AI, paste it. A green tick shows when the AI calls back.
struct PromptConnect: View {
    let key: String
    let name: String
    let tint: Color
    let site: String
    @ObservedObject var store = LinkStore.shared
    @Environment(\.palette) var p
    @Environment(\.openURL) var openURL
    @State var busy = false
    @State var note = ""
    @State var copiedId = ""
    var mine: [LinkAI] { store.links.filter { $0.key == key } }

    func step(_ n: String, _ t: String) -> some View {
        HStack(alignment: .top, spacing: 10) { Image(systemName: n).foregroundColor(tint).font(.title3); Text(t).font(.subheadline).foregroundColor(p.ink) }
    }
    func nextLabel() -> String { mine.isEmpty ? name : "\(name) \(mine.count + 1)" }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PipSays(text: "No key needed. About 30 seconds. Make a prompt, paste it into \(name), done.")
            step("1.circle.fill", "Tap Make my prompt.")
            step("2.circle.fill", "Tap Copy, then Open \(name) and paste it in a chat.")
            step("3.circle.fill", "When \(name) answers, a green tick shows here.")
            ForEach(mine) { l in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: l.seen ? "checkmark.circle.fill" : "hourglass").foregroundColor(l.seen ? .sprout : .orange)
                        Text(l.label).font(.headline).foregroundColor(p.ink)
                        Spacer()
                        Text(l.seen ? "Connected" : "Waiting for first reply").font(.caption.bold()).foregroundColor(l.seen ? .sprout : .orange)
                            .accessibilityIdentifier("linkStatus-" + l.id)
                    }
                    HStack(spacing: 8) {
                        Button { if let t = store.token(l) { UIPasteboard.general.string = LinkPrompt.text(name: l.label, token: t); copiedId = l.id } } label: {
                            Label(copiedId == l.id ? "Copied" : "Copy prompt", systemImage: "doc.on.doc.fill")
                        }.buttonStyle(PrimaryButton()).accessibilityIdentifier("cpPrompt-" + key)
                        Button { if let u = URL(string: site) { openURL(u) } } label: { Label("Open \(name)", systemImage: "arrow.up.right.square.fill") }
                            .buttonStyle(SoftButton()).accessibilityIdentifier("openAI-" + key)
                    }
                    Button("Remove this one") { Task { await store.remove(l) } }.font(.footnote).foregroundColor(p.soft)
                }.padding(12).background(Color.white.opacity(0.6)).clipShape(RoundedRectangle(cornerRadius: 16))
            }
            Button { Task { busy = true; note = await store.make(key: key, label: nextLabel()) ?? ""; busy = false } } label: {
                Label(busy ? "Making..." : (mine.isEmpty ? "Make my prompt" : "Add another \(name)"), systemImage: "wand.and.stars")
            }.buttonStyle(mine.isEmpty ? AnyButtonStyle(PrimaryButton()) : AnyButtonStyle(SoftButton())).disabled(busy).accessibilityIdentifier("mkPrompt-" + key)
            if !note.isEmpty { Text(note).font(.footnote).foregroundColor(p.soft) }
            Text("Your token stays on this phone and in your private link. Never post it in a public place.").font(.caption).foregroundColor(p.soft)
        }
        .task { await store.refresh() }
        .task(id: store.pending) {
            while store.pending > 0 && !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                await store.refresh()
            }
        }
    }
}

struct AnyButtonStyle: ButtonStyle {
    private let make: (ButtonStyleConfiguration) -> AnyView
    init<S: ButtonStyle>(_ s: S) { make = { AnyView(s.makeBody(configuration: $0)) } }
    func makeBody(configuration: Configuration) -> some View { make(configuration) }
}

/// Link-only AIs: no API at all, or the user prefers a prompt.
struct LinkOnlyTile: View {
    let key: String, name: String, blurb: String, icon: String, tint: Color, site: String
    @Binding var openId: String?
    @ObservedObject var store = LinkStore.shared
    @Environment(\.palette) var p
    var open: Bool { openId == key }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button { withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) { openId = open ? nil : key } } label: {
                HStack(spacing: 12) {
                    IconTile(icon: icon, color: tint)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(name).font(.system(.headline, design: .rounded)).foregroundColor(p.ink)
                        Text(store.connectedCount(key) > 0 ? "Connected" : blurb).font(.caption).foregroundColor(store.connectedCount(key) > 0 ? .sprout : p.soft)
                    }
                    Spacer()
                    Image(systemName: "chevron.down").foregroundColor(tint).rotationEffect(.degrees(open ? 180 : 0))
                }
                .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                .background(p.card).clipShape(RoundedRectangle(cornerRadius: 22))
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(open ? tint : Color.clear, lineWidth: 2))
                .contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityIdentifier("ai-" + key)
            if open { PromptConnect(key: key, name: name, tint: tint, site: site) }
        }
    }
}
