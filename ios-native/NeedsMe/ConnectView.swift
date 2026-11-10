import SwiftUI

let setupPrompt = "You are my friendly setup helper for the NeedsMe Ai app. Help me connect my own AI in under 60 seconds. Ask me ONE question at a time: 1) Which AI do I want to connect (OpenAI, Claude or Gemini)? 2) Give me the exact key page link and the 3 clicks to create an API key. 3) Tell me to copy the key and paste it ONLY into the NeedsMe app Connect page, never into this chat. 4) Tell me which model name to type. 5) Ask me to press Test connection and tell you the result. Use short plain words. If something fails, give the single next fix."

struct ConnectView: View {
    @Environment(\.palette) var p
    @State private var copied = false
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
                        Text("No AI is connected yet. Pick a route below for each AI: your own key, or the hand off route. A hand off is never shown as a live link.").font(.subheadline).foregroundColor(p.ink).accessibilityIdentifier("connectionStatus")
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
    AIRoute(id: "perplexity", name: "Perplexity", kind: "Hand-off", how: "Copy your question, open Perplexity, paste the answer back.", url: "https://www.perplexity.ai"),
    AIRoute(id: "grok", name: "Grok", kind: "Hand-off", how: "Copy your question, open Grok, paste the answer back.", url: "https://grok.com"),
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
