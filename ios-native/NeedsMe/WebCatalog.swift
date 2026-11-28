import Foundation

/// Every AI the app can open as a real website. Same list as the Mac app.
struct WebAI: Identifiable, Equatable {
    let id: String
    let name: String
    let url: String
    let group: String
}

let webCatalog: [WebAI] = [
    WebAI(id: "chatgpt", name: "ChatGPT", url: "https://chatgpt.com/", group: "Chat"),
    WebAI(id: "claude", name: "Claude", url: "https://claude.ai/", group: "Chat"),
    WebAI(id: "gemini", name: "Gemini", url: "https://gemini.google.com/app", group: "Chat"),
    WebAI(id: "grok", name: "Grok", url: "https://grok.com/", group: "Chat"),
    WebAI(id: "muse", name: "Muse (Meta)", url: "https://muse.ai/", group: "Agent"),
    WebAI(id: "metaai", name: "Meta AI", url: "https://www.meta.ai/", group: "Chat"),
    WebAI(id: "copilot", name: "Microsoft Copilot", url: "https://copilot.microsoft.com/", group: "Chat"),
    WebAI(id: "perplexity", name: "Perplexity", url: "https://www.perplexity.ai/", group: "Chat"),
    WebAI(id: "deepseek", name: "DeepSeek", url: "https://chat.deepseek.com/", group: "Chat"),
    WebAI(id: "mistral", name: "Le Chat (Mistral)", url: "https://chat.mistral.ai/chat", group: "Chat"),
    WebAI(id: "qwen", name: "Qwen", url: "https://chat.qwen.ai/", group: "Chat"),
    WebAI(id: "kimi", name: "Kimi", url: "https://www.kimi.com/", group: "Chat"),
    WebAI(id: "zai", name: "Z.ai (GLM)", url: "https://chat.z.ai/", group: "Chat"),
    WebAI(id: "poe", name: "Poe", url: "https://poe.com/", group: "Chat"),
    WebAI(id: "you", name: "You.com", url: "https://you.com/", group: "Chat"),
    WebAI(id: "pi", name: "Pi", url: "https://pi.ai/", group: "Chat"),
    WebAI(id: "character", name: "Character.AI", url: "https://character.ai/", group: "Chat"),
    WebAI(id: "hugging", name: "HuggingChat", url: "https://huggingface.co/chat/", group: "Chat"),
    WebAI(id: "duck", name: "Duck.ai", url: "https://duck.ai/", group: "Chat"),
    WebAI(id: "phind", name: "Phind", url: "https://www.phind.com/", group: "Chat"),
    WebAI(id: "cohere", name: "Cohere North / Playground", url: "https://dashboard.cohere.com/playground/chat", group: "Chat"),
    WebAI(id: "ernie", name: "ERNIE Bot", url: "https://ernie.baidu.com/", group: "Chat"),
    WebAI(id: "doubao", name: "Doubao", url: "https://www.doubao.com/chat/", group: "Chat"),
    WebAI(id: "yuanbao", name: "Tencent Yuanbao", url: "https://yuanbao.tencent.com/", group: "Chat"),
    WebAI(id: "manus", name: "Manus", url: "https://manus.im/app", group: "Agent"),
    WebAI(id: "genspark", name: "Genspark", url: "https://www.genspark.ai/", group: "Agent"),
    WebAI(id: "notebooklm", name: "NotebookLM", url: "https://notebooklm.google.com/", group: "Research"),
    WebAI(id: "jules", name: "Jules (Google)", url: "https://jules.google.com/", group: "Coding"),
    WebAI(id: "codex", name: "ChatGPT Codex", url: "https://chatgpt.com/codex", group: "Coding"),
    WebAI(id: "claudecode", name: "Claude Code (web)", url: "https://claude.ai/code", group: "Coding"),
    WebAI(id: "copilotgh", name: "GitHub Copilot", url: "https://github.com/copilot", group: "Coding"),
    WebAI(id: "devin", name: "Devin", url: "https://app.devin.ai/", group: "Coding"),
    WebAI(id: "cursor", name: "Cursor (web agents)", url: "https://cursor.com/agents", group: "Coding"),
    WebAI(id: "replit", name: "Replit Agent", url: "https://replit.com/", group: "Coding"),
    WebAI(id: "lovable", name: "Lovable", url: "https://lovable.dev/", group: "Builder"),
    WebAI(id: "bolt", name: "Bolt", url: "https://bolt.new/", group: "Builder"),
    WebAI(id: "v0", name: "v0 (Vercel)", url: "https://v0.dev/", group: "Builder"),
    WebAI(id: "gamma", name: "Gamma", url: "https://gamma.app/", group: "Builder"),
    WebAI(id: "midjourney", name: "Midjourney", url: "https://www.midjourney.com/", group: "Images"),
    WebAI(id: "ideogram", name: "Ideogram", url: "https://ideogram.ai/", group: "Images"),
    WebAI(id: "runway", name: "Runway", url: "https://app.runwayml.com/", group: "Video"),
    WebAI(id: "suno", name: "Suno", url: "https://suno.com/", group: "Music"),
    WebAI(id: "eleven", name: "ElevenLabs", url: "https://elevenlabs.io/app", group: "Voice"),
    WebAI(id: "polar", name: "Polar", url: "https://polarbrowser.com/", group: "Agent"),
    WebAI(id: "opencode", name: "OpenCode", url: "https://opencode.ai/", group: "Coding"),
    WebAI(id: "custom", name: "Any other AI (paste its link)", url: "", group: "Any"),
    WebAI(id: "claudecli", name: "Claude Code (terminal)", url: "", group: "Coding"),
    WebAI(id: "codexcli", name: "Codex CLI", url: "", group: "Coding"),
    WebAI(id: "geminicli", name: "Gemini CLI", url: "", group: "Coding"),
]

func webAI(_ id: String) -> WebAI? { webCatalog.first { $0.id == id } }
