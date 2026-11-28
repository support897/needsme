import SwiftUI
import WebKit
import UserNotifications

/// Which alerts each account may send. Saved on this phone only. All on by default.
@MainActor
final class AlertPrefs: ObservableObject {
    static let shared = AlertPrefs()
    @Published var tick = 0
    private let key = "needsme.alertPrefs"
    private var map: [String: [String: Bool]] { (UserDefaults.standard.dictionary(forKey: key) as? [String: [String: Bool]]) ?? [:] }
    func on(_ id: String, _ kind: String) -> Bool { map[id]?[kind] ?? true }
    /// From the shared list (another device changed it). No permission prompt here.
    func importFlags(_ id: String, done: Bool, needs: Bool, msgs: Bool, chats: Bool = true, uneeds: Bool = true, updates: Bool = true) {
        var m = map; m[id] = ["done": done, "needs": needs, "msgs": msgs, "uchats": chats, "uneeds": uneeds, "uupdates": updates]
        UserDefaults.standard.set(m, forKey: key)
    }
    func set(_ v: Bool, _ id: String, _ kind: String) {
        var m = map; var a = m[id] ?? [:]; a[kind] = v; m[id] = a
        UserDefaults.standard.set(m, forKey: key); tick += 1
        if v, !["uchats", "uneeds", "uupdates"].contains(kind) { UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in } }
    }
}

/// Carries a tapped alert to the right account, and knows which account is on screen.
@MainActor
final class AlertRouter: ObservableObject {
    static let shared = AlertRouter()
    @Published var open: AIAccount?
    var viewing: String?
    var screenUp = false
    func go(_ id: String) { if let a = AIConnections.shared.account(id) { open = a } }
}

/// Looks at each open AI page now and then. When a reply finishes or a new message lands,
/// it sends a phone alert that opens that account. Runs while the app is open, and for a short
/// while after you leave it. iOS stops all pages when the app is fully closed.
@MainActor
final class AlertWatcher {
    static let shared = AlertWatcher()
    private var started = false
    private var wasBusy: [String: Bool] = [:]
    private var lastTail: [String: String] = [:]
    private var bg: UIBackgroundTaskIdentifier = .invalid

    static let probe = #"(()=>{const b=!!document.querySelector('button[aria-label*="Stop" i],[data-testid*="stop" i],button[aria-label*="stop generating" i],[aria-label*="Stop response" i]');const q=document.querySelectorAll('[data-message-author-role="assistant"],[data-testid="assistant-message"],.font-claude-message,.font-claude-response,message-content,.model-response-text,[data-test-render-count],.markdown');const l=q.length?q[q.length-1]:null;const t=((l&&l.innerText)||(document.body&&document.body.innerText)||'').trim();return JSON.stringify({b:b,t:t.slice(-600)})})()"#

    func start() {
        guard !started else { return }; started = true
        CheckIns.schedule(); CrashReporter.start()
        NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.holdOn() }
        }
        Task { @MainActor in
            while true {
                try? await Task.sleep(nanoseconds: 6_000_000_000)
                await self.scan()
                if let s = Store.current { await AutoPull.run(store: s) }
            }
        }
    }
    private func holdOn() {
        if bg != .invalid { UIApplication.shared.endBackgroundTask(bg) }
        bg = UIApplication.shared.beginBackgroundTask { [weak self] in
            guard let self else { return }
            if self.bg != .invalid { UIApplication.shared.endBackgroundTask(self.bg); self.bg = .invalid }
        }
    }

    func scan() async {
        for id in OpenTabs.shared.seen {
            guard let a = AIConnections.shared.account(id), let v = WebHub.existing(id) else { continue }
            if !AlertPrefs.shared.on(id, "uneeds") && !AlertPrefs.shared.on(id, "uupdates") { continue }
            let s = await WebHub.js(v, Self.probe)
            guard let d = s.data(using: .utf8), let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else { continue }
            let busy = j["b"] as? Bool ?? false
            let tail = j["t"] as? String ?? ""
            let prevBusy = wasBusy[id], prevTail = lastTail[id]
            wasBusy[id] = busy; lastTail[id] = tail
            guard prevBusy != nil, let pt = prevTail else { continue }
            let watching = AlertRouter.shared.screenUp && AlertRouter.shared.viewing == id && UIApplication.shared.applicationState == .active
            if watching { continue }
            if prevBusy == true && !busy, AlertPrefs.shared.on(id, "done") {
                post(a, "Finished", "\(a.label) is done.")
            } else if !busy && tail != pt && !tail.isEmpty, AlertPrefs.shared.on(id, "needs"), Self.asksYou(tail) {
                post(a, "Needs you", String(tail.suffix(240)))
                // fill the Needs You list, if she turned "Use it as NeedsMe" on for this AI
                if AlertPrefs.shared.on(id, "uneeds") { Store.current?.addNeed(text: String(tail.suffix(240)), ai: a.label, roomId: "", project: "", url: a.url ?? webAI(a.provider)?.url ?? "") }
            } else if !busy && tail != pt && !tail.isEmpty, AlertPrefs.shared.on(id, "msgs") {
                post(a, "New message", String(tail.suffix(240)))
            }
        }
    }
    static func asksYou(_ t: String) -> Bool {
        let s = t.lowercased()
        return ["do you want me to", "would you like me to", "which one", "please confirm", "waiting for your", "need your approval"].contains { s.contains($0) }
    }

    func post(_ a: AIAccount, _ title: String, _ body: String) {
        let c = UNMutableNotificationContent()
        c.title = (a.label == a.platformName ? a.label : a.platformName + " \u{00B7} " + a.label); c.subtitle = title; c.body = body; c.sound = .default
        c.userInfo = ["acct": a.id]
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: c, trigger: nil))
    }
}

/// The alert ticks, shown in the account editor.
struct AlertTicks: View {
    let id: String
    @ObservedObject private var prefs = AlertPrefs.shared
    @Environment(\.palette) var p
    func row(_ title: String, _ kind: String) -> some View {
        Toggle(title, isOn: Binding(get: { prefs.on(id, kind) }, set: { prefs.set($0, id, kind) }))
            .tint(.sprout).foregroundColor(p.ink).accessibilityIdentifier("alert-" + kind)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Alerts").font(.headline).foregroundColor(p.ink)
            row("When it finishes a job", "done")
            row("When it needs me", "needs")
            row("When a new message comes", "msgs")
            Text("Use this AI in NeedsMe").font(.headline).foregroundColor(p.ink).padding(.top, 6)
            row("Pull its chats and projects", "uchats")
            row("Use it as NeedsMe (find what needs me)", "uneeds")
            row("Show its updates", "uupdates")
            Text("Tap an alert to open this account. Alerts come while the app is open or just after you leave it. These choices follow you to your other devices.").font(.footnote).foregroundColor(p.soft)
        }.id(prefs.tick)
    }
}
