import SwiftUI
import FirebaseAuth

/// Live door for AIs that have no key route (Polar, Claude Code, Copilot and others).
/// Makes a private link and token on the NeedsMe bridge. Provider keys are never sent to it.
struct BridgeCard: View {
    @Environment(\.palette) var p
    static let base = "https://billowing-lake-5abc.placenciailse.workers.dev"
    @State private var token = ""
    @State private var note = ""
    @State private var busy = false
    var body: some View {
        Card {
            Text("LIVE LINK").font(.caption.monospaced().bold()).foregroundColor(p.soft)
            Text("Connect Polar and other AI tools").font(.title3.bold()).foregroundColor(p.ink)
            Text("Make a private link. Paste it into Polar, Claude Code or any tool that supports MCP. Your AI keys are not shared.").font(.subheadline).foregroundColor(p.soft)
            if token.isEmpty {
                Button(busy ? "Making..." : "Make my link") { Task { await make() } }
                    .buttonStyle(PrimaryButton()).disabled(busy).accessibilityIdentifier("bridgeMake")
            } else {
                Button("Copy link") { UIPasteboard.general.string = BridgeCard.base + "/mcp"; note = "Link copied." }.buttonStyle(SoftButton())
                Button("Copy token") { UIPasteboard.general.string = token; note = "Token copied. Paste it as the Bearer token." }.buttonStyle(SoftButton())
            }
            if !note.isEmpty { Text(note).font(.footnote).foregroundColor(p.soft) }
        }
    }
    func make() async {
        busy = true; note = ""; defer { busy = false }
        guard let u = Auth.auth().currentUser, let idt = try? await u.getIDToken(), let url = URL(string: BridgeCard.base + "/tokens") else { note = "Sign in first."; return }
        var r = URLRequest(url: url); r.httpMethod = "POST"; r.timeoutInterval = 30
        r.setValue("Bearer " + idt, forHTTPHeaderField: "Authorization")
        guard let (d, resp) = try? await URLSession.shared.data(for: r), (resp as? HTTPURLResponse)?.statusCode == 200,
              let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any], let t = j["token"] as? String else { note = "Could not make a link. Try again."; return }
        token = t
        BridgeSync.shared.saveToken(t)
        note = "Live link is ON. Updates from your AI arrive in the app."
    }
}
