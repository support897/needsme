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
        if !AIConsent.granted { return AIConsent.needed }
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
    /// Steps for adding the connector, per AI. Honest about plans.
    static func guide(_ key: String, _ name: String) -> (page: String, steps: [String], plan: String) {
        switch key {
        case "claude": return ("https://claude.ai/customize/connectors", [
            "Open Claude on the web (claude.ai) and sign in.",
            "Go to Settings, then Connectors (or Plugins). Tap Add custom connector.",
            "Name it the same as here. Paste the link you copied. Leave the sign-in boxes empty. Tap Add.",
            "Start a new chat. When Claude asks to use a NeedsMe tool, tap Always allow.",
            "Paste the prompt in that chat. A green tick shows here."], "Works on the free plan (one custom connector). Paid plans can add more.")
        case "chatgpt": return ("https://chatgpt.com/plugins", [
            "Open ChatGPT on the web (chatgpt.com), not the phone app.",
            "Open Plugins, tap Add, then Add custom MCP server.",
            "Name it the same as here. Paste the link. Set sign-in to No authentication. Tick the risk box and create it.",
            "Open a new chat, type @ and pick it. Tap Allow when asked.",
            "Paste the prompt. A green tick shows here."], "Needs a paid plan. Plus and Pro can read but may not post replies, so for a full chat use your API key instead. Business and Enterprise work fully.")
        case "perplexity": return ("https://www.perplexity.ai/", [
            "Open Perplexity on the web and sign in.",
            "Open Plugins (or Settings, Connectors). Tap Add custom, then Add MCP connector, then Remote.",
            "Name it the same as here. Paste the link. Under Advanced set sign-in to None and transport to Streamable HTTP. Tick the box, tap Add.",
            "Tap the new connector card to turn it on. Switch it on under Sources in a chat.",
            "Paste the prompt. A green tick shows here."], "Needs Pro or higher.")
        case "grok": return ("https://grok.com/connectors", [
            "Open grok.com/connectors and sign in.",
            "Tap New Connector, then Custom.",
            "Name it the same as here. Paste the link. Leave sign-in empty. Save.",
            "Start a new chat. Grok uses the connector when your question fits.",
            "Paste the prompt. A green tick shows here."], "Needs a paid Grok plan.")
        case "opencode": return ("https://opencode.ai/docs/mcp-servers/", [
            "Open a terminal on your computer. OpenCode must be installed.",
            "Tap Copy terminal command below. Paste it in the terminal and press Enter.",
            "Start OpenCode. Ask: \"Call get_my_projects from NeedsMe.\"",
            "Paste the prompt in the chat. A green tick shows here.",
            "If it asks you to sign in, add \"oauth\": false to the NeedsMe entry in opencode.json."], "Free. Works with any model OpenCode uses. Not yet tested with a real OpenCode by us.")
        case "codex": return ("https://developers.openai.com/codex/mcp", [
            "Open a terminal on your computer. Codex must be installed.",
            "Tap Copy terminal command below. Paste it in the terminal and press Enter.",
            "Run codex mcp list. You should see your name there.",
            "Start Codex and paste the prompt. A green tick shows here."], "Works with Codex CLI, and the Codex app shares the same setting. Not yet tested with a real Codex by us.")
        default: return (key == "polar" ? "https://polarbrowser.com" : "https://www.google.com/search?q=" + name.replacingOccurrences(of: " ", with: "+") + "+add+custom+MCP+connector", [
            "Open \(name) and find its connectors or MCP settings.",
            "Add a custom or remote MCP server. Name it the same as here. Paste the link. No sign-in.",
            "Start a new chat and allow the NeedsMe tools.",
            "Paste the prompt. A green tick shows here."], "If \(name) cannot add a connector, it cannot join by link. Use an API key instead if it has one.")
        }
    }
    /// One line for the terminal. The link holds the token, so keep it private.
    static func command(_ key: String, label: String, link: String) -> String {
        let slug = label.lowercased().map { $0.isLetter || $0.isNumber ? String($0) : "-" }.joined()
        return key == "opencode" ? "opencode mcp add \(slug) --url \(link)" : "codex mcp add \(slug) --url \(link)"
    }
    /// The chat prompt. It holds no token. The token lives only in the connector link.
    static func text(name: String, token: String) -> String {
        """
        You are "\(name)" in my NeedsMe, through the NeedsMe connector I just added. Use its tools:
        1. Call get_my_projects and use my exact project names. In your first reply say exactly: Connected: I can see N projects (N = how many projects get_my_projects returned).
        2. After every reply where something changed, call report_update (project, summary, todos_new, todos_done, needs_you, finished, chat_url = the web link to this chat). Use needs_you only when you cannot go on without my answer.
        3. At the start of every reply call check_inbox. If something is addressed to you, answer it with post_message (use the room named in the message, author "\(name)") and write @name to bring in another AI. If you can keep running, call wait_for_message again and again so you answer the moment someone @mentions you.
        4. If you cannot see the NeedsMe tools, tell me. Do not ask me for a token.
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
    @State var newName = ""
    @State var showSteps = true
    var mine: [LinkAI] { store.links.filter { $0.key == key } }

    func step(_ n: String, _ t: String) -> some View {
        HStack(alignment: .top, spacing: 10) { Image(systemName: n).foregroundColor(tint).font(.title3); Text(t).font(.subheadline).foregroundColor(p.ink) }
    }
    func nextLabel() -> String { mine.isEmpty ? name : "\(name) \(mine.count + 1)" }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PipSays(text: "No key needed. Make a link, add it to \(name) as a connector, then paste the prompt. Each link gets its own name, so you can add the same AI many times.")
            let g = LinkPrompt.guide(key, name)
            DisclosureGroup("How to connect \(name)", isExpanded: $showSteps) {
                VStack(alignment: .leading, spacing: 8) {
                    step("1.circle.fill", "Name it below and tap Make my link.")
                    ForEach(Array(g.steps.enumerated()), id: \.offset) { i, t in step("\(i + 2).circle.fill", t) }
                    Text(g.plan).font(.footnote.bold()).foregroundColor(p.soft)
                    Button { if let u = URL(string: g.page) { openURL(u) } } label: { Label("Open \(name) connector page", systemImage: "arrow.up.right.square.fill") }
                        .buttonStyle(SoftButton()).accessibilityIdentifier("openAI-" + key)
                }.padding(.top, 6)
            }.accessibilityIdentifier("howto-" + key).tint(tint)
            ForEach(mine) { l in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: l.seen ? "checkmark.circle.fill" : "hourglass").foregroundColor(l.seen ? .sprout : .orange)
                        Text(l.label).font(.headline).foregroundColor(p.ink)
                        Spacer()
                        Text(l.seen ? "Connected" : "Waiting for first reply").font(.caption.bold()).foregroundColor(l.seen ? .sprout : .orange)
                            .accessibilityIdentifier("linkStatus-" + l.id)
                    }
                    Button { if let t = store.token(l) { UIPasteboard.general.string = BridgeCard.base + "/mcp/" + t; copiedId = "L" + l.id } } label: {
                        Label(copiedId == "L" + l.id ? "Link copied" : "Copy link for connector", systemImage: "link")
                    }.buttonStyle(SoftButton()).accessibilityIdentifier("cpLink-" + key)
                    if key == "opencode" || key == "codex" {
                        Button { if let t = store.token(l) { UIPasteboard.general.string = LinkPrompt.command(key, label: l.label, link: BridgeCard.base + "/mcp/" + t); copiedId = "C" + l.id } } label: {
                            Label(copiedId == "C" + l.id ? "Command copied" : "Copy terminal command", systemImage: "terminal.fill")
                        }.buttonStyle(SoftButton()).accessibilityIdentifier("cpCmd-" + key)
                    }
                    HStack(spacing: 8) {
                        Button { if let t = store.token(l) { UIPasteboard.general.string = LinkPrompt.text(name: l.label, token: t); copiedId = l.id } } label: {
                            Label(copiedId == l.id ? "Copied" : "Copy prompt", systemImage: "doc.on.doc.fill")
                        }.buttonStyle(PrimaryButton()).accessibilityIdentifier("cpPrompt-" + key)
                    }
                    Button("Remove this one") { Task { await store.remove(l) } }.font(.footnote).foregroundColor(p.soft)
                }.padding(12).background(Color.white.opacity(0.6)).clipShape(RoundedRectangle(cornerRadius: 16))
            }
            TextField(nextLabel(), text: $newName).textFieldStyle(.roundedBorder).accessibilityIdentifier("linkName-" + key)
                .textInputAutocapitalization(.words).autocorrectionDisabled()
            Text("Use this exact name in \(name) too. To add another \(name), give it a new name, like \"\(name) Work\".").font(.caption).foregroundColor(p.soft)
            Button { Task {
                let want = newName.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "@", with: "")
                let label = want.isEmpty ? nextLabel() : String(want.prefix(30))
                if store.links.contains(where: { $0.label.lowercased() == label.lowercased() }) { note = "That name is taken. Pick another."; return }
                busy = true; note = await store.make(key: key, label: label) ?? ""; busy = false; if note.isEmpty { newName = "" } } } label: {
                Label(busy ? "Making..." : (mine.isEmpty ? "Make my link" : "Add another \(name)"), systemImage: "wand.and.stars")
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
