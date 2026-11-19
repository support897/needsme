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
    @State private var pname = "My AI"
    func prompt(_ t: String) -> String {
        """
        Connect to my NeedsMe. It is my own private link. Add it as an MCP server (or custom connector) with these details:
        URL: \(BridgeCard.base)/mcp
        Header: Authorization: Bearer \(t)
        Rules for you:
        1. Call get_my_projects first, and use my exact project names.
        2. After every reply where something changed, call report_update (project, summary, todos_new, todos_done, needs_you, finished, chat_url = the web link to this chat).
        3. Use needs_you only when you cannot go on without my answer.
        4. To bring in another AI, call post_message and write @name (for example @gemini).
        5. Never share this token with anyone. If you cannot add MCP servers, tell me, and I will give you the paste-block rule instead.
        """
    }
    var body: some View {
        Card {
            Text("LIVE LINK").font(.caption.monospaced().bold()).foregroundColor(p.soft)
            Text("Connect Polar and other AI tools").font(.title3.bold()).foregroundColor(p.ink)
            Text("Your own private link. Only you can use it. Your AI keys are never sent to it. Each AI gets its own token, so you can cut one off alone.").font(.subheadline).foregroundColor(p.soft)
            TextField("Name this AI (for example Claude)", text: $pname).textFieldStyle(.roundedBorder).accessibilityIdentifier("bridgeName")
            Button(busy ? "Making..." : "Make a link for this AI") { Task { await make() } }
                .buttonStyle(PrimaryButton()).disabled(busy).accessibilityIdentifier("bridgeMake")
            if !token.isEmpty {
                Button("Copy prompt for my AI") { UIPasteboard.general.string = prompt(token); note = "Prompt copied. Paste it into your AI's chat." }.buttonStyle(PrimaryButton()).accessibilityIdentifier("bridgePrompt")
                Button("Copy link only") { UIPasteboard.general.string = BridgeCard.base + "/mcp"; note = "Link copied." }.buttonStyle(SoftButton())
                Button("Copy token only") { UIPasteboard.general.string = token; note = "Token copied. Paste it as the Bearer token." }.buttonStyle(SoftButton())
            }
            Button("Cut off all my links") { Task { await revoke("/tokens/all", "All links are off. Make new ones when you want.") } }.buttonStyle(SoftButton()).accessibilityIdentifier("bridgeRevoke")
            Button("Erase everything on the link") { Task { await revoke("/me", "Erased. The link kept nothing of yours.") } }.buttonStyle(SoftButton()).accessibilityIdentifier("bridgeErase")
            if !note.isEmpty { Text(note).font(.footnote).foregroundColor(p.soft) }
        }
    }
    func revoke(_ path: String, _ done: String) async {
        guard let u = Auth.auth().currentUser, let idt = try? await u.getIDToken(), let url = URL(string: BridgeCard.base + path) else { note = "Sign in first."; return }
        var r = URLRequest(url: url); r.httpMethod = "DELETE"; r.timeoutInterval = 30
        r.setValue("Bearer " + idt, forHTTPHeaderField: "Authorization")
        guard let (_, resp) = try? await URLSession.shared.data(for: r), (resp as? HTTPURLResponse)?.statusCode == 200 else { note = "Could not do that. Try again."; return }
        token = ""; BridgeSync.shared.clearToken(); note = done
    }
    func make() async {
        busy = true; note = ""; defer { busy = false }
        guard let u = Auth.auth().currentUser, let idt = try? await u.getIDToken(), let url = URL(string: BridgeCard.base + "/tokens") else { note = "Sign in first."; return }
        var r = URLRequest(url: url); r.httpMethod = "POST"; r.timeoutInterval = 30
        r.setValue("Bearer " + idt, forHTTPHeaderField: "Authorization"); r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        r.httpBody = try? JSONSerialization.data(withJSONObject: ["name": pname])
        guard let (d, resp) = try? await URLSession.shared.data(for: r), (resp as? HTTPURLResponse)?.statusCode == 200,
              let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any], let t = j["token"] as? String else { note = "Could not make a link (10 is the limit). Try again."; return }
        token = t
        if BridgeSync.shared.token == nil { BridgeSync.shared.saveToken(t) }
        note = "Link made for \(pname). Tap Copy prompt, then paste it into that AI."
    }
}
