import SwiftUI

let setupPrompt = "You are my friendly setup helper for the NeedsMe Ai app. Help me connect my own AI in under 60 seconds. Ask me ONE question at a time: 1) Which AI do I want to connect (OpenAI, Claude or Gemini)? 2) Give me the exact key page link and the 3 clicks to create an API key. 3) Tell me to copy the key and paste it ONLY into the NeedsMe app Connect page, never into this chat. 4) Tell me which model name to type. 5) Ask me to press Test connection and tell you the result. Use short plain words. If something fails, give the single next fix."

struct ConnectView: View {
    @Environment(\.palette) var p
    @State private var copied = false
    @State private var openId: String? = nil
    @State private var wizard = false
    @ObservedObject private var conns = AIConnections.shared
    var statusLines: String {
        conns.accounts.map { a in "\(a.label): \(conns.status(a))" + ((conns.status(a) == "Connected" ? conns.connectSeconds[a.id] : nil).map { String(format: " in %.1f s", $0) } ?? "") }.joined(separator: "\n")
    }
    var connectedCount: Int { AIProvider.allCases.filter { conns.isConnected(conns.account($0.rawValue) ?? AIAccount(id: $0.rawValue, provider: $0.rawValue, label: $0.name)) }.count }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Card {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Set up, with Pip.").font(.system(.title2, design: .rounded).weight(.heavy))
                            Text("\(connectedCount) of \(AIProvider.allCases.count) AIs connected").font(.subheadline.weight(.semibold)).foregroundColor(p.soft)
                            StepDots(count: AIProvider.allCases.count, current: max(connectedCount - 1, 0))
                        }
                        Spacer(); PipArt(pose: .welcome, height: 70)
                    }.foregroundColor(p.ink)
                    Button { wizard = true } label: { Label("Start Pip's setup", systemImage: "wand.and.stars") }
                        .buttonStyle(PrimaryButton()).accessibilityIdentifier("startWizard")
                    Button(copied ? "Copied. Paste it into your AI." : "Copy setup prompt") {
                        UIPasteboard.general.string = setupPrompt; copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { copied = false }
                    }.buttonStyle(SoftButton())
                    Text(statusLines).font(.caption).foregroundColor(p.soft).accessibilityIdentifier("connectionStatus")
                }
                FoldSection(id: "updates", icon: "checklist.checked", color: Color(hex: 0xA8C256), title: "Progress, to-dos and alerts", sub: "How your AIs report back to you") { UpdatesCard() }
                Text("Pick an AI. Tap it to see the steps.").font(.system(.headline, design: .rounded)).foregroundColor(p.ink).padding(.top, 4)
                ForEach(AIProvider.allCases) { prov in AITile(prov: prov, openId: $openId) }
                Text("More ways in").font(.system(.headline, design: .rounded)).foregroundColor(p.ink).padding(.top, 8)
                FoldSection(id: "signin", icon: "person.crop.circle.badge.checkmark", color: Color(hex: 0x4285F4), title: "Sign in with your AI account", sub: "Bring your chats in") { SignInDoorCard() }
                FoldSection(id: "import", icon: "square.and.arrow.down.fill", color: Color(hex: 0x10A37F), title: "Take your projects out of an AI", sub: "Import from an export file") { ProjectImportCard() }
                FoldSection(id: "bring", icon: "key.horizontal.fill", color: Color(hex: 0xD97757), title: "Bring my keys in", sub: "Already saved keys on another phone") { BringKeysCard() }
                FoldSection(id: "bridge", icon: "link.circle.fill", color: Color(hex: 0x8B5CF6), title: "Polar, Claude Code and other tools", sub: "Make a live link") { BridgeCard(); CustomMCPCard(); WorkToolsCard() }
                FoldSection(id: "handoff", icon: "arrow.left.arrow.right.circle.fill", color: Color(hex: 0xF55036), title: "Copy and paste AIs", sub: "Copilot, Codex, Cursor and more") { AIRoutesCard() }
                Text("Never paste your key into a chat. Keep it private.").font(.footnote).foregroundColor(p.soft)
            }.padding()
        }
        .hidesTabBar().lookBg().navigationTitle("Connections")
        .sheet(isPresented: $wizard) { SetupWizard(onClose: { wizard = false }) }
    }
}

/// Every AI gets a real, honestly named route. No "coming soon" bucket.
/// Own key = you make a key at the AI's own page. Hand-off = the app copies your question,
/// opens that AI's own app or page, and you paste the answer back into a note. Nothing here
/// pretends to be a live link between the AI and this app. (HTML section 13 catalogue:
/// method, capabilities, permissions, setup and limitations stand on every entry.)
struct AIRoute: Identifiable {
    let id: String; let name: String; let kind: String; let how: String; let url: String
    let category: String; let caps: String; let perms: String; let limits: String
}
let aiRoutes: [AIRoute] = [
    AIRoute(id: "chatgpt", name: "ChatGPT / OpenAI", kind: "Own key", how: "Make a key, then use it in your AI app. Or hand off a question to ChatGPT.", url: "https://platform.openai.com/api-keys", category: "AI assistants and models", caps: "Answers in rooms · reads talks · files to-dos", perms: "Your key is used only for calls you start", limits: "Needs credit on your OpenAI account to answer"),
    AIRoute(id: "claude", name: "Claude", kind: "Own key", how: "Make a key at Anthropic, or hand off a question to Claude.", url: "https://console.anthropic.com/settings/keys", category: "AI assistants and models", caps: "Answers in rooms · reads talks · files to-dos", perms: "Your key is used only for calls you start", limits: "Needs credit on your Anthropic account to answer"),
    AIRoute(id: "gemini", name: "Gemini", kind: "Own key", how: "Make a key at Google AI Studio, or hand off a question to Gemini.", url: "https://aistudio.google.com/apikey", category: "AI assistants and models", caps: "Answers in rooms · reads talks · files to-dos", perms: "Your key is used only for calls you start", limits: "Free keys have daily limits"),
    AIRoute(id: "perplexity", name: "Perplexity", kind: "Own key", how: "Make a key at Perplexity, paste it above, then test it.", url: "https://www.perplexity.ai", category: "AI assistants and models", caps: "Answers in rooms · reads talks · files to-dos", perms: "Your key is used only for calls you start", limits: "Needs credit on your Perplexity account to answer"),
    AIRoute(id: "grok", name: "Grok", kind: "Own key", how: "Make a key at xAI, paste it above, then test it.", url: "https://grok.com", category: "AI assistants and models", caps: "Answers in rooms · reads talks · files to-dos", perms: "Your key is used only for calls you start", limits: "Needs credit on your xAI account to answer"),
    AIRoute(id: "copilot", name: "Microsoft Copilot", kind: "Hand-off", how: "Copy your question, open Copilot, paste the answer back into a note.", url: "https://copilot.microsoft.com", category: "AI assistants and models", caps: "Hand-off questions and answers", perms: "Nothing is shared until you paste it", limits: "No live link. A carry, not a connection"),
    AIRoute(id: "claudecode", name: "Claude Code", kind: "Hand-off", how: "Copy a project prompt, paste it in Claude Code on your computer, bring the result back.", url: "https://claude.com/product/claude-code", category: "AI coding", caps: "Hand-off project prompts", perms: "Nothing is shared until you paste it", limits: "No live link in this build. The connection design is in the build notes"),
    AIRoute(id: "codex", name: "Codex", kind: "Hand-off", how: "Copy a project prompt, open Codex, bring the result back.", url: "https://chatgpt.com/codex", category: "AI coding", caps: "Hand-off project prompts", perms: "Nothing is shared until you paste it", limits: "No live link. A carry, not a connection"),
    AIRoute(id: "cursor", name: "Cursor", kind: "Hand-off", how: "Copy a project prompt, paste it in Cursor, bring the result back.", url: "https://cursor.com", category: "AI coding", caps: "Hand-off project prompts", perms: "Nothing is shared until you paste it", limits: "No live link. A carry, not a connection"),
    AIRoute(id: "polar", name: "Polar", kind: "Hand-off", how: "Copy a task prompt, open Polar, bring the result back.", url: "https://polarbrowser.com", category: "AI browsers and research", caps: "Hand-off task prompts", perms: "Nothing is shared until you paste it", limits: "No live link. A carry, not a connection"),
    AIRoute(id: "muse", name: "Muse", kind: "Own key", how: "Make a key at dev.meta.ai (Model API), paste it above, then test it.", url: "https://dev.meta.ai", category: "AI assistants and models", caps: "Answers in rooms · reads talks · files to-dos", perms: "Your key is used only for calls you start", limits: "Meta Model API is pay as you go; public preview, US developers first"),
    AIRoute(id: "deepseek", name: "DeepSeek", kind: "Own key", how: "Make a key at platform.deepseek.com, paste it above, then test it.", url: "https://platform.deepseek.com", category: "AI assistants and models", caps: "Answers in rooms · reads talks · files to-dos", perms: "Your key is used only for calls you start", limits: "Pay as you go at the provider"),
    AIRoute(id: "mistral", name: "Mistral", kind: "Own key", how: "Make a key at console.mistral.ai, paste it above, then test it.", url: "https://console.mistral.ai", category: "AI assistants and models", caps: "Answers in rooms · reads talks · files to-dos", perms: "Your key is used only for calls you start", limits: "Pay as you go at the provider"),
    AIRoute(id: "groq", name: "Groq (Llama and more)", kind: "Own key", how: "Make a key at console.groq.com, paste it above, then test it.", url: "https://console.groq.com", category: "AI assistants and models", caps: "Answers in rooms · reads talks · files to-dos", perms: "Your key is used only for calls you start", limits: "Pay as you go at the provider"),
    AIRoute(id: "openrouter", name: "OpenRouter (hundreds of models)", kind: "Own key", how: "Make a key at openrouter.ai, paste it above, then test it.", url: "https://openrouter.ai", category: "AI assistants and models", caps: "Answers in rooms · reads talks · files to-dos", perms: "Your key is used only for calls you start", limits: "Pay as you go at the provider"),
]
let aiCategories = ["AI assistants and models", "AI coding", "AI browsers and research"]

struct AIRoutesCard: View {
    @Environment(\.palette) var p
    @Environment(\.openURL) var openURL
    @ObservedObject private var conns = AIConnections.shared
    @State private var copiedId = ""
    var body: some View {
        Card {
            Text("EVERY AI HAS A WAY IN").font(.caption.monospaced().bold()).foregroundColor(p.soft)
            Text("Pick your AI").font(.title3.bold()).foregroundColor(p.ink)
            Text("Own key: you make a key at that AI. Hand-off: the app copies your question, opens that AI, and you paste the answer back. Hand-off is a carry, not a live link, and we say so.")
                .font(.subheadline).foregroundColor(p.soft)
            ForEach(aiCategories, id: \.self) { cat in
                Text(cat).font(.headline).foregroundColor(p.ink).padding(.top, 8)
                ForEach(aiRoutes.filter { $0.category == cat }) { r in routeRow(r) }
            }
        }
    }

    func routeRow(_ r: AIRoute) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack { Text(r.name).font(.body.weight(.semibold)).foregroundColor(p.ink); Spacer()
                Text(r.kind).font(.caption.bold()).foregroundColor(p.soft) }
            Text(r.how).font(.footnote).foregroundColor(p.soft)
            Text("Can do: " + r.caps).font(.footnote).foregroundColor(p.soft)
            Text("Permissions: " + r.perms).font(.footnote).foregroundColor(p.soft)
            Text("Limits: " + r.limits).font(.footnote).foregroundColor(p.soft)
            if let acc = conns.account(r.id), let res = conns.results[acc.id] {
                Text("Last tested: " + Store.niceTime(res.at)).font(.footnote).foregroundColor(p.soft)
            }
            Button(copiedId == r.id ? "Copied. Opening..." : (r.url.isEmpty ? "Copy question" : "Copy question and open")) {
                UIPasteboard.general.string = "Question from my NeedsMe Ai project:\n\n"
                copiedId = r.id
                if let u = URL(string: r.url), !r.url.isEmpty { openURL(u) }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { copiedId = "" }
            }.buttonStyle(SoftButton()).accessibilityIdentifier("route-" + r.id)
        }.padding(.vertical, 6)
    }
}

/// Work tools (HTML section 13): named in the catalogue, with the truth about their path.
/// None has a supported way into this app yet, so none carries a Connect button.
struct WorkToolsCard: View {
    @Environment(\.palette) var p
    let tools = ["GitHub", "Notion", "Google Drive", "Slack", "Discord", "Email", "Calendar"]
    var body: some View {
        Card {
            Text("WORK TOOLS").font(.caption.monospaced().bold()).foregroundColor(p.soft)
            Text("Work and project tools").font(.title3.bold()).foregroundColor(p.ink)
            ForEach(tools, id: \.self) { t in
                VStack(alignment: .leading, spacing: 2) {
                    Text(t).font(.body.weight(.semibold)).foregroundColor(p.ink)
                    Text("No supported path into this app yet. Nothing here pretends to connect it.")
                        .font(.footnote).foregroundColor(p.soft)
                }.padding(.vertical, 4)
            }
        }
    }
}

/// Custom connections (HTML section 13): a user can write down an MCP server they own.
/// Saving a server never shows it as connected: it stands as saved on this phone only,
/// until a real connection test exists and passes.
struct CustomMCPCard: View {
    @Environment(\.palette) var p
    @State private var name = ""
    @State private var address = ""
    @State private var saved: [[String: String]] = CustomMCPCard.load()
    static let storeKey = "nm_custom_mcp"
    static func load() -> [[String: String]] {
        (UserDefaults.standard.array(forKey: storeKey) as? [[String: String]]) ?? []
    }
    func persist() { UserDefaults.standard.set(saved, forKey: CustomMCPCard.storeKey) }

    var body: some View {
        Card {
            Text("CUSTOM CONNECTION").font(.caption.monospaced().bold()).foregroundColor(p.soft)
            Text("Add your own MCP server").font(.title3.bold()).foregroundColor(p.ink)
            Text("Write down a server you own. It is saved on this phone only. Saved is not connected: a server here never shows as a live worker until a real test passes.")
                .font(.subheadline).foregroundColor(p.soft)
            ForEach(saved.indices, id: \.self) { i in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(saved[i]["name"] ?? "").font(.body.weight(.semibold)).foregroundColor(p.ink)
                        Text(saved[i]["address"] ?? "").font(.caption).foregroundColor(p.soft)
                        Text("Saved on this phone. Not connected.").font(.caption.bold()).foregroundColor(p.soft)
                    }
                    Spacer()
                    Button("Remove") { saved.remove(at: i); persist() }.buttonStyle(SoftButton())
                }.padding(.vertical, 4)
            }
            TextField("Server name", text: $name)
                .autocorrectionDisabled()
                .padding(10).background(p.chip).clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(p.line, lineWidth: 1))
                .foregroundColor(p.ink).accessibilityIdentifier("mcpName")
            TextField("Server address", text: $address)
                .autocorrectionDisabled().textInputAutocapitalization(.never)
                .padding(10).background(p.chip).clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(p.line, lineWidth: 1))
                .foregroundColor(p.ink).accessibilityIdentifier("mcpAddress")
            Button("Save server") {
                let n = name.trimmingCharacters(in: .whitespaces)
                let a = address.trimmingCharacters(in: .whitespaces)
                guard !n.isEmpty, !a.isEmpty else { return }
                saved.append(["name": n, "address": a]); persist(); name = ""; address = ""
            }.buttonStyle(SoftButton()).accessibilityIdentifier("mcpSave")
        }
    }
}

/// Each own key provider holds a list of accounts. An account is its own key plus its own label.
/// Keys go to the Keychain only. The screen never shows a key again.
struct KeysCard: View {
    @Environment(\.palette) var p
    @Environment(\.openURL) var openURL
    @ObservedObject private var conns = AIConnections.shared
    @State private var drafts: [String: String] = [:]
    @State private var labels: [String: String] = [:]
    @State private var notes: [String: String] = [:]
    @State private var adding: String? = nil
    @State private var newLabel = ""
    @State private var newKey = ""

    var body: some View {
        Card {
            Text("YOUR OWN KEYS").font(.caption.monospaced().bold()).foregroundColor(p.soft)
            Text("Connect with your key").font(.title3.bold()).foregroundColor(p.ink)
            Text("Each key is one account with its own name. Two keys from one AI are two voices in a room. Your key stays on this phone, in the Keychain. It is never sent to our servers.")
                .font(.subheadline).foregroundColor(p.soft)
            ForEach(AIProvider.allCases) { prov in
                VStack(alignment: .leading, spacing: 10) {
                    Text(prov.name + " (" + prov.company + ")").font(.headline).foregroundColor(p.ink)
                    ForEach(conns.accounts(for: prov)) { a in row(a) }
                    if adding == prov.rawValue { addForm(prov) } else {
                        Button("Add another account") {
                            adding = prov.rawValue; newLabel = conns.nextDefaultLabel(prov); newKey = ""
                        }.buttonStyle(SoftButton()).accessibilityIdentifier("addAccount-" + prov.rawValue)
                    }
                    Button("Get a key") { if let u = URL(string: prov.keyPage) { openURL(u) } }
                        .buttonStyle(SoftButton()).accessibilityIdentifier("getKey-" + prov.rawValue)
                }.padding(.vertical, 8)
            }
        }
    }

    func field(_ placeholder: String, _ text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .autocorrectionDisabled()
            .padding(10).background(p.chip).clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(p.line, lineWidth: 1))
            .foregroundColor(p.ink)
    }
    func secure(_ placeholder: String, _ text: Binding<String>) -> some View {
        SecureField(placeholder, text: text)
            .autocorrectionDisabled().textInputAutocapitalization(.never)
            .padding(10).background(p.chip).clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(p.line, lineWidth: 1))
            .foregroundColor(p.ink)
    }

    func row(_ a: AIAccount) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(a.label).font(.body.weight(.semibold)).foregroundColor(p.ink)
                Spacer()
                Text(conns.status(a)).font(.caption.bold()).foregroundColor(p.ink)
                    .accessibilityIdentifier("status-" + a.id)
            }
            field("Name in rooms", Binding(get: { labels[a.id] ?? a.label }, set: { labels[a.id] = $0 }))
                .onSubmit { commitLabel(a) }
                .accessibilityIdentifier("label-" + a.id)
            secure(conns.hasKey(a) ? "A key is saved. Paste a new one to replace it." : "Paste your key",
                   Binding(get: { drafts[a.id] ?? "" }, set: { drafts[a.id] = $0 }))
                .accessibilityIdentifier("keyField-" + a.id)
            HStack(spacing: 8) {
                Button("Save") {
                    commitLabel(a)
                    let k = drafts[a.id] ?? ""
                    if k.isEmpty { notes[a.id] = conns.hasKey(a) ? "Name saved." : "Paste a key first." }
                    else { notes[a.id] = conns.save(k, for: a) ? "Saved on this phone." : "Could not save the key." }
                    drafts[a.id] = ""
                }.buttonStyle(SoftButton()).accessibilityIdentifier("saveKey-" + a.id)
                Button("Test connection") {
                    Task { await conns.test(a) }
                }.buttonStyle(SoftButton()).accessibilityIdentifier("testKey-" + a.id)
            }
            if conns.hasKey(a) || a.id != a.provider {
                Button(a.id == a.provider ? "Remove key" : "Remove account") {
                    conns.remove(a); notes[a.id] = "Removed."
                }.buttonStyle(SoftButton()).accessibilityIdentifier("removeKey-" + a.id)
            }
            if let n = notes[a.id], !n.isEmpty { Text(n).font(.footnote).foregroundColor(p.soft) }
        }
        .padding(12).background(p.chip).clipShape(RoundedRectangle(cornerRadius: 12))
    }

    func commitLabel(_ a: AIAccount) {
        if let l = labels[a.id], !l.trimmingCharacters(in: .whitespaces).isEmpty { conns.rename(a, to: l) }
        labels[a.id] = nil
    }

    func addForm(_ prov: AIProvider) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("New " + prov.name + " account").font(.subheadline.weight(.semibold)).foregroundColor(p.ink)
            field("Name in rooms", $newLabel).accessibilityIdentifier("newLabel-" + prov.rawValue)
            secure("Paste the key", $newKey).accessibilityIdentifier("newKey-" + prov.rawValue)
            HStack(spacing: 8) {
                Button("Save account") {
                    if conns.add(provider: prov, label: newLabel, key: newKey) != nil { adding = nil; newKey = ""; newLabel = "" }
                }.buttonStyle(SoftButton()).accessibilityIdentifier("saveNew-" + prov.rawValue)
                Button("Cancel") { adding = nil; newKey = "" }
                    .buttonStyle(SoftButton()).accessibilityIdentifier("cancelNew-" + prov.rawValue)
            }
        }
        .padding(12).background(p.chip).clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
