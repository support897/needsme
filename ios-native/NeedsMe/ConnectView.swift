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
