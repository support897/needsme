import SwiftUI

/// "Projects shared with your AIs": when the bridge last got your projects, and when each AI last asked for them.
struct SharedStatusCard: View {
    @Environment(\.palette) var p
    @EnvironmentObject var store: Store
    @ObservedObject var sync = BridgeSync.shared
    @State var loaded = false
    @State var snapshotAt: Double = 0
    @State var count = 0
    @State var ais: [(name: String, at: Double)] = []
    @State var note = ""

    func ago(_ ms: Double) -> String {
        if ms <= 0 { return "never" }
        let f = RelativeDateTimeFormatter(); f.unitsStyle = .full
        return f.localizedString(for: Date(timeIntervalSince1970: ms / 1000), relativeTo: Date())
    }
    func load() async {
        guard let t = sync.token, let url = URL(string: BridgeCard.base + "/status") else { note = "Make a link to an AI first."; loaded = true; return }
        var r = URLRequest(url: url); r.timeoutInterval = 20
        r.setValue("Bearer " + t, forHTTPHeaderField: "Authorization")
        guard let (d, resp) = try? await URLSession.shared.data(for: r), (resp as? HTTPURLResponse)?.statusCode == 200,
              let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else { note = "Could not reach the link. Try again."; loaded = true; return }
        snapshotAt = (j["snapshotAt"] as? Double) ?? 0
        count = (j["projects"] as? Int) ?? 0
        ais = ((j["ais"] as? [[String: Any]]) ?? []).map { (($0["name"] as? String) ?? "AI", ($0["lastProjectsCall"] as? Double) ?? 0) }
        note = ""; loaded = true
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Projects shared with your AIs").font(.headline).foregroundColor(p.ink)
            Text("This phone has \(store.projects.count) project\(store.projects.count == 1 ? "" : "s"). The link holds \(count).").font(.subheadline).foregroundColor(p.ink)
                .accessibilityIdentifier("sharedCount")
            Text("Link last got your projects: " + ago(snapshotAt)).font(.subheadline).foregroundColor(p.soft)
                .accessibilityIdentifier("sharedSnapshot")
            if ais.isEmpty && loaded && note.isEmpty { Text("No AI has asked for your projects yet. Paste the prompt in an AI chat.").font(.footnote).foregroundColor(p.soft) }
            ForEach(Array(ais.enumerated()), id: \.offset) { _, a in
                HStack { Image(systemName: "checkmark.circle.fill").foregroundColor(.sprout); Text(a.name + " asked " + ago(a.at)).font(.subheadline).foregroundColor(p.ink) }
            }
            if !note.isEmpty { Text(note).font(.footnote).foregroundColor(p.soft) }
            Button { Task { await load() } } label: { Label("Check now", systemImage: "arrow.clockwise") }
                .buttonStyle(SoftButton()).accessibilityIdentifier("sharedCheck")
        }
        .task { await load() }
    }
}
