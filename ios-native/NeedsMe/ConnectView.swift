import SwiftUI

let setupPrompt = "You are my friendly setup helper for the NeedsMe Ai app. Help me connect my own AI in under 60 seconds. Ask me ONE question at a time: 1) Which AI do I want to connect (OpenAI, Claude or Gemini)? 2) Give me the exact key page link and the 3 clicks to create an API key. 3) Tell me to copy the key and paste it ONLY into the NeedsMe app Connect page, never into this chat. 4) Tell me which model name to type. 5) Ask me to press Test connection and tell you the result. Use short plain words. If something fails, give the single next fix."

struct ConnectView: View {
    @Environment(\.palette) var p
    @State private var copied = false
    @ObservedObject private var conns = AIConnections.shared
    var statusLines: String {
        conns.accounts.map { "\($0.label): \(conns.status($0))" }.joined(separator: "\n")
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Card {
                        HStack { VStack(alignment: .leading) { Text("Set up, with Pip.").font(.title2.bold()); Text("Connect an AI in about a minute.").foregroundColor(p.soft) }; Spacer(); PipImage(size: 60) }.foregroundColor(p.ink)
                    }
                    Card {
                        Text("60 SECONDS").font(.caption.monospaced().bold()).foregroundColor(p.soft)
                        Text("Set up your AI fast").font(.title3.bold()).foregroundColor(p.ink)
                        step(1, "Open your AI's key page"); step(2, "Make a key and copy it"); step(3, "Paste it in your AI app and save")
                        HStack {
                            Link("OpenAI key", destination: URL(string: "https://platform.openai.com/api-keys")!).buttonStyle(SoftButton())
                            Link("Claude key", destination: URL(string: "https://console.anthropic.com/settings/keys")!).buttonStyle(SoftButton())
                            Link("Gemini key", destination: URL(string: "https://aistudio.google.com/apikey")!).buttonStyle(SoftButton())
                        }
                        Text("Stuck? Copy a helper prompt and paste it into any AI you already use. It will walk you through, one step at a time.").font(.subheadline).foregroundColor(p.soft)
                        Button(copied ? "Copied. Paste it into your AI." : "Copy setup prompt") {
                            UIPasteboard.general.string = setupPrompt; copied = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { copied = false }
                        }.buttonStyle(PrimaryButton())
                        Text("Never paste your key into a chat. Keep it private.").font(.footnote).foregroundColor(p.soft)
                    }
                    Card {
                        Text("Connection status").font(.headline).foregroundColor(p.ink)
                        Text(statusLines).font(.subheadline).foregroundColor(p.ink).accessibilityIdentifier("connectionStatus")
                        Text("An AI shows Connected only after its own test passed on this phone. A hand off is never shown as a live link.").font(.footnote).foregroundColor(p.soft)
                    }
                    KeysCard()
                    Card {
                        Text("Rooms").font(.headline).foregroundColor(p.ink)
                        Text("Talk to your connected AIs in one room. Mention them by name.").font(.subheadline).foregroundColor(p.soft)
                        NavigationLink { RoomsListView() } label: { Text("Open rooms").font(.system(.body, design: .rounded).weight(.semibold)).frame(maxWidth: .infinity).padding(.vertical, 12).background(p.chip).foregroundColor(p.ink).clipShape(Capsule()) }
                            .accessibilityIdentifier("openRooms")
                    }
                    AIRoutesCard()
                }.padding()
            }.background(p.bg).navigationTitle("Connect")
        }
    }
    func step(_ n: Int, _ t: String) -> some View {
        HStack(spacing: 10) {
            Text("\(n)").font(.subheadline.bold()).frame(width: 28, height: 28).background(p.accent).foregroundColor(p.accentInk).clipShape(Circle())
            Text(t).font(.body.weight(.semibold)).foregroundColor(p.ink)
        }
    }
}

/// Every AI gets a real, honestly named route. No "coming soon" bucket.
/// Own key = you make a key at the AI's own page. Hand-off = the app copies your question,
/// opens that AI's own app or page, and you paste the answer back into a note. Nothing here
/// pretends to be a live link between the AI and this app.
struct AIRoute: Identifiable {
    let id: String; let name: String; let kind: String; let how: String; let url: String
}
let aiRoutes: [AIRoute] = [
    AIRoute(id: "chatgpt", name: "ChatGPT / OpenAI", kind: "Own key", how: "Make a key, then use it in your AI app. Or hand off a question to ChatGPT.", url: "https://platform.openai.com/api-keys"),
    AIRoute(id: "claude", name: "Claude", kind: "Own key", how: "Make a key at Anthropic, or hand off a question to Claude.", url: "https://console.anthropic.com/settings/keys"),
    AIRoute(id: "gemini", name: "Gemini", kind: "Own key", how: "Make a key at Google AI Studio, or hand off a question to Gemini.", url: "https://aistudio.google.com/apikey"),
    AIRoute(id: "copilot", name: "Microsoft Copilot", kind: "Hand-off", how: "Copy your question, open Copilot, paste the answer back into a note.", url: "https://copilot.microsoft.com"),
    AIRoute(id: "claudecode", name: "Claude Code", kind: "Hand-off", how: "Copy a project prompt, paste it in Claude Code on your computer, bring the result back.", url: "https://claude.com/product/claude-code"),
    AIRoute(id: "codex", name: "Codex", kind: "Hand-off", how: "Copy a project prompt, open Codex, bring the result back.", url: "https://chatgpt.com/codex"),
    AIRoute(id: "cursor", name: "Cursor", kind: "Hand-off", how: "Copy a project prompt, paste it in Cursor, bring the result back.", url: "https://cursor.com"),
    AIRoute(id: "polar", name: "Polar", kind: "Hand-off", how: "Copy a task prompt, open Polar, bring the result back.", url: "https://polarbrowser.com"),
    AIRoute(id: "muse", name: "Muse", kind: "Hand-off", how: "Copy a task prompt, open Muse, bring the result back. (No link: open Muse yourself.)", url: ""),
    AIRoute(id: "perplexity", name: "Perplexity", kind: "Own key", how: "Make a key at Perplexity, paste it above, then test it.", url: "https://www.perplexity.ai"),
    AIRoute(id: "grok", name: "Grok", kind: "Own key", how: "Make a key at xAI, paste it above, then test it.", url: "https://grok.com"),
]

struct AIRoutesCard: View {
    @Environment(\.palette) var p
    @Environment(\.openURL) var openURL
    @State private var copiedId = ""
    var body: some View {
        Card {
            Text("EVERY AI HAS A WAY IN").font(.caption.monospaced().bold()).foregroundColor(p.soft)
            Text("Pick your AI").font(.title3.bold()).foregroundColor(p.ink)
            Text("Own key: you make a key at that AI. Hand-off: the app copies your question, opens that AI, and you paste the answer back. Hand-off is a carry, not a live link, and we say so.")
                .font(.subheadline).foregroundColor(p.soft)
            ForEach(aiRoutes) { r in
                VStack(alignment: .leading, spacing: 6) {
                    HStack { Text(r.name).font(.body.weight(.semibold)).foregroundColor(p.ink); Spacer()
                        Text(r.kind).font(.caption.bold()).foregroundColor(p.soft) }
                    Text(r.how).font(.footnote).foregroundColor(p.soft)
                    Button(copiedId == r.id ? "Copied. Opening..." : (r.url.isEmpty ? "Copy question" : "Copy question and open")) {
                        UIPasteboard.general.string = "Question from my NeedsMe Ai project:\n\n"
                        copiedId = r.id
                        if let u = URL(string: r.url), !r.url.isEmpty { openURL(u) }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { copiedId = "" }
                    }.buttonStyle(SoftButton()).accessibilityIdentifier("route-" + r.id)
                }.padding(.vertical, 6)
            }
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
            .padding(10).background(p.bg).clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(p.line, lineWidth: 1))
            .foregroundColor(p.ink)
    }
    func secure(_ placeholder: String, _ text: Binding<String>) -> some View {
        SecureField(placeholder, text: text)
            .autocorrectionDisabled().textInputAutocapitalization(.never)
            .padding(10).background(p.bg).clipShape(RoundedRectangle(cornerRadius: 10))
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
        .padding(12).background(p.bg.opacity(0.5)).clipShape(RoundedRectangle(cornerRadius: 12))
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
        .padding(12).background(p.bg.opacity(0.5)).clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
