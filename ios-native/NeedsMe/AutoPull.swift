import Foundation
import WebKit

/// Items 4, 15: with "Pull its chats and projects" on, NeedsMe reads each signed-in AI's own projects and chat titles
/// through that AI's page on this phone (no button), every 10 minutes while the app is open, and files them.
/// Only ChatGPT and Claude expose them to a page session; other AIs use the export file picker.
@MainActor
enum AutoPull {
    private static var last: [String: Date] = [:]
    private static let started = Date()
    static func run(store: Store) async {
        guard store.user != nil, Date().timeIntervalSince(started) > 20 else { return }
        for id in OpenTabs.shared.seen {
            guard let a = AIConnections.shared.account(id), AlertPrefs.shared.on(id, "uchats"),
                  let js = DoorReader.js(a.provider), let v = WebHub.existing(id) else { continue }
            if let t = last[id], Date().timeIntervalSince(t) < 600 { continue }
            last[id] = Date()
            guard let res = try? await v.callAsyncJavaScript(js, arguments: [:], in: nil, contentWorld: .page),
                  let s = res as? String, let r = DoorReader.decode(s), r.err == nil else { continue }
            let projects = (r.projects ?? []).compactMap { x -> ProjectImport.Found? in
                let n = (x.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                return n.isEmpty ? nil : ProjectImport.Found(name: n, about: x.about ?? "")
            }
            let src = a.label == a.platformName ? a.platformName : a.platformName + " " + a.label
            _ = DoorFiler.file(store, source: src, projects: projects, chats: r.chats ?? [])
        }
    }
}
