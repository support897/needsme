import SwiftUI

// Step by step, colourful building blocks. One thing at a time, tap to open the next.

extension AIProvider {
    /// Each AI gets its own colour and its own icon, so a row is known at a glance.
    var tint: Color {
        switch self {
        case .chatgpt: return Color(hex: 0x10A37F)
        case .claude: return Color(hex: 0xD97757)
        case .gemini: return Color(hex: 0x4285F4)
        case .perplexity: return Color(hex: 0x20B8CD)
        case .grok: return Color(hex: 0x4B5563)
        case .muse: return Color(hex: 0x0866FF)
        case .deepseek: return Color(hex: 0x4D6BFE)
        case .mistral: return Color(hex: 0xFA5310)
        case .groq: return Color(hex: 0xF55036)
        case .openrouter: return Color(hex: 0x8B5CF6)
        }
    }
    var icon: String {
        switch self {
        case .chatgpt: return "sparkles"
        case .claude: return "asterisk"
        case .gemini: return "star.fill"
        case .perplexity: return "magnifyingglass"
        case .grok: return "bolt.fill"
        case .muse: return "wand.and.stars"
        case .deepseek: return "water.waves"
        case .mistral: return "wind"
        case .groq: return "speedometer"
        case .openrouter: return "arrow.triangle.branch"
        }
    }
    var blurb: String {
        switch self {
        case .chatgpt: return "Writes and plans"
        case .claude: return "Thinks things through"
        case .gemini: return "Free key, fast"
        case .perplexity: return "Finds answers"
        case .grok: return "Quick and witty"
        case .muse: return "From Meta"
        case .deepseek: return "Low cost"
        case .mistral: return "Light and quick"
        case .groq: return "Very fast, free tier"
        case .openrouter: return "Hundreds of models"
        }
    }
}

/// A round coloured icon.
struct IconTile: View {
    let icon: String
    let color: Color
    var size: CGFloat = 44
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.32).fill(LinearGradient(colors: [color, color.opacity(0.72)], startPoint: .topLeading, endPoint: .bottomTrailing))
            Image(systemName: icon).font(.system(size: size * 0.46, weight: .bold)).foregroundColor(.white)
        }.frame(width: size, height: size).accessibilityHidden(true)
    }
}

/// Pip talks in a speech bubble.
struct PipSays: View {
    let text: String
    var pose: PipPose = .welcome
    @Environment(\.palette) var p
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            PipArt(pose: pose, height: 58)
            Text(text).font(.system(.subheadline, design: .rounded).weight(.semibold)).foregroundColor(p.ink)
                .padding(12).background(p.chip).clipShape(RoundedRectangle(cornerRadius: 18))
        }
    }
}

struct StepDots: View {
    let count: Int
    let current: Int
    var color: Color = .sprout
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { i in
                Capsule().fill(i <= current ? color : color.opacity(0.25)).frame(width: i == current ? 22 : 8, height: 8)
            }
        }.accessibilityHidden(true)
    }
}

/// A colourful row that opens to show more. Closed by default, so a screen is a short list, not a wall.
struct FoldSection<Content: View>: View {
    let id: String
    let icon: String
    let color: Color
    let title: String
    let sub: String
    var startOpen = false
    @State var open: Bool? = nil
    @ViewBuilder var content: Content
    @Environment(\.palette) var p
    var isOpen: Bool { open ?? startOpen }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .trailing) {
                Button { withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) { open = !isOpen } } label: {
                    HStack(spacing: 12) {
                        IconTile(icon: icon, color: color)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(title).font(.system(.headline, design: .rounded)).foregroundColor(p.ink)
                            Text(sub).font(.caption).foregroundColor(p.soft).multilineTextAlignment(.leading)
                        }
                        Spacer(minLength: 30)
                    }
                    .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                    .background(p.card).clipShape(RoundedRectangle(cornerRadius: 22))
                    .shadow(color: Color.loam.opacity(p.isDark ? 0 : 0.07), radius: 10, y: 5)
                }.buttonStyle(.plain).accessibilityIdentifier("fold-" + id)
                Image(systemName: "chevron.down").font(.system(size: 14, weight: .bold)).foregroundColor(color)
                    .rotationEffect(.degrees(isOpen ? 180 : 0)).padding(.trailing, 16).allowsHitTesting(false)
            }
            if isOpen { content.transition(.opacity.combined(with: .move(edge: .top))) }
        }
    }
}

/// How AIs wake each other, shown as a tiny animated chat.
struct WakeStory: View {
    @Environment(\.palette) var p
    @State var shown = 0
    let lines: [(String, String, Color)] = [
        ("You", "@Claude plan our launch", Color.sprout),
        ("Claude", "Done. @Gemini please check the dates.", AIProvider.claude.tint),
        ("Gemini", "Dates look good. All set!", AIProvider.gemini.tint),
    ]
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(0..<lines.count, id: \.self) { i in
                if i < shown {
                    HStack(alignment: .top, spacing: 8) {
                        Circle().fill(lines[i].2).frame(width: 28, height: 28)
                            .overlay(Text(String(lines[i].0.prefix(1))).font(.system(size: 13, weight: .heavy)).foregroundColor(.white))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(lines[i].0).font(.caption.bold()).foregroundColor(p.soft)
                            Text(lines[i].1).font(.system(.subheadline, design: .rounded)).foregroundColor(p.ink)
                                .padding(10).background(p.chip).clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }.transition(.scale(scale: 0.9, anchor: .topLeading).combined(with: .opacity))
                }
            }
            HStack(spacing: 6) {
                Image(systemName: "at").foregroundColor(.sprout)
                Text("Type @ and an AI's name. That AI wakes up, reads the room and answers.").font(.footnote).foregroundColor(p.soft)
            }
            HStack(spacing: 6) {
                Image(systemName: "repeat").foregroundColor(.sprout)
                Text("An AI can @ another AI too. After 6 AI replies in a row, the room waits for you.").font(.footnote).foregroundColor(p.soft)
            }
            HStack(spacing: 6) {
                Image(systemName: "iphone").foregroundColor(.sprout)
                Text("They wake while the app is open on your phone.").font(.footnote).foregroundColor(p.soft)
            }
            Button("Play again") { play() }.buttonStyle(SoftButton()).accessibilityIdentifier("wakePlay")
        }
        .onAppear { play() }
    }
    func play() {
        shown = 0
        for i in 1...lines.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.9) { withAnimation(.spring()) { shown = i } }
        }
    }
}

/// One AI, one step at a time: 1 Get a key, 2 Paste it, 3 Test it. More settings are one tap away.
struct ProviderPanel: View {
    let prov: AIProvider
    @Environment(\.palette) var p
    @Environment(\.openURL) var openURL
    @ObservedObject var conns = AIConnections.shared
    @State var step = 1
    @State var draft = ""
    @State var note = ""
    @State var more = false
    @State var adding = false
    @State var newLabel = ""
    @State var newKey = ""
    @State var labels: [String: String] = [:]
    @State var drafts: [String: String] = [:]

    var main: AIAccount { conns.account(prov.rawValue) ?? AIAccount(id: prov.rawValue, provider: prov.rawValue, label: prov.name) }

    func chip(_ n: Int, _ title: String, _ icon: String, done: Bool) -> some View {
        Button { withAnimation(.easeInOut(duration: 0.2)) { step = n } } label: {
            VStack(spacing: 4) {
                Image(systemName: done ? "checkmark.circle.fill" : icon).font(.system(size: 18, weight: .bold))
                Text(title).font(.system(size: 11, weight: .bold, design: .rounded))
            }
            .frame(maxWidth: .infinity).padding(.vertical, 8)
            .background(step == n ? prov.tint : p.chip).foregroundColor(step == n ? .white : p.ink)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }.buttonStyle(.plain).accessibilityIdentifier("step-\(prov.rawValue)-\(n)")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                chip(1, "Get key", "key.fill", done: conns.hasKey(main))
                chip(2, "Paste", "doc.on.clipboard.fill", done: conns.hasKey(main))
                chip(3, "Test", "bolt.heart.fill", done: conns.isConnected(main))
            }
            if step == 1 {
                PipSays(text: "A key is like a password for \(prov.name). Make one at their site. It takes a minute.")
                tip("1.circle.fill", "Sign in at \(prov.company)")
                tip("2.circle.fill", "Tap Create key")
                tip("3.circle.fill", "Copy it, then come back here")
                Button { if let u = URL(string: prov.keyPage) { openURL(u) } } label: {
                    Label("Open \(prov.name) key page", systemImage: "arrow.up.right.square.fill")
                }.buttonStyle(PrimaryButton()).accessibilityIdentifier("getKey-" + prov.rawValue)
                Button("I have my key") { withAnimation { step = 2 } }.buttonStyle(SoftButton()).accessibilityIdentifier("haveKey-" + prov.rawValue)
            } else if step == 2 {
                PipSays(text: "Paste it here. It stays on this phone, never on our servers.", pose: .point)
                SecureField(conns.hasKey(main) ? "A key is saved. Paste a new one to replace it." : "Paste your key", text: $draft)
                    .autocorrectionDisabled().textInputAutocapitalization(.never)
                    .padding(12).background(p.chip).clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(prov.tint.opacity(0.5), lineWidth: 1.5))
                    .foregroundColor(p.ink).accessibilityIdentifier("keyField-" + prov.rawValue)
                Button { saveKey() } label: { Label("Save key", systemImage: "lock.fill") }
                    .buttonStyle(PrimaryButton()).accessibilityIdentifier("saveKey-" + prov.rawValue)
            } else {
                PipSays(text: conns.isConnected(main) ? "Connected! Say @\(main.label) in a group chat to wake it." : "Let's check it works. Tap the button.", pose: conns.isConnected(main) ? .celebrate : .welcome)
                Button { Task { await conns.test(main) } } label: {
                    Label(conns.testing.contains(main.id) ? "Testing..." : "Test connection", systemImage: "bolt.fill")
                }.buttonStyle(PrimaryButton()).accessibilityIdentifier("testKey-" + prov.rawValue)
                if conns.testing.contains(main.id) { ProgressView().frame(maxWidth: .infinity) }
                if let s = conns.connectSeconds[main.id], conns.isConnected(main) {
                    Text(String(format: "Connected in %.1f seconds", s)).font(.footnote.bold()).foregroundColor(prov.tint)
                }
            }
            if !note.isEmpty { Text(note).font(.footnote).foregroundColor(p.soft) }
            Button { withAnimation { more.toggle() } } label: {
                HStack { Image(systemName: "gearshape.fill"); Text(more ? "Hide settings" : "More settings"); Spacer(); Image(systemName: more ? "chevron.up" : "chevron.down") }
                    .font(.system(.subheadline, design: .rounded).weight(.semibold)).foregroundColor(p.soft)
            }.buttonStyle(.plain).accessibilityIdentifier("settings-" + prov.rawValue)
            if more { settings }
        }
        .padding(14).background(p.card).clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(prov.tint.opacity(0.35), lineWidth: 1.5))
    }

    func tip(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 10) { Image(systemName: icon).foregroundColor(prov.tint).font(.title3); Text(text).font(.system(.subheadline, design: .rounded)).foregroundColor(p.ink) }
    }

    func saveKey() {
        let k = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        if k.isEmpty { note = conns.hasKey(main) ? "Your key is already saved." : "Paste a key first."; return }
        if conns.save(k, for: main) { note = "Saved on this phone."; draft = ""; withAnimation { step = 3 } } else { note = "Could not save the key." }
    }

    @ViewBuilder var settings: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Name in rooms").font(.caption.bold()).foregroundColor(p.soft)
            TextField("Name in rooms", text: Binding(get: { labels[main.id] ?? main.label }, set: { labels[main.id] = $0 }))
                .autocorrectionDisabled().padding(10).background(p.chip).clipShape(RoundedRectangle(cornerRadius: 10)).foregroundColor(p.ink)
                .onSubmit { commit(main) }.accessibilityIdentifier("label-" + main.id)
            if conns.hasKey(main) {
                Button("Remove key") { conns.remove(main); note = "Removed." }.buttonStyle(SoftButton()).accessibilityIdentifier("removeKey-" + main.id)
            }
            ForEach(conns.accounts(for: prov).filter { $0.id != main.id }) { a in extra(a) }
            if adding {
                VStack(alignment: .leading, spacing: 8) {
                    Text("New \(prov.name) account").font(.subheadline.weight(.semibold)).foregroundColor(p.ink)
                    TextField("Name in rooms", text: $newLabel).autocorrectionDisabled()
                        .padding(10).background(p.chip).clipShape(RoundedRectangle(cornerRadius: 10)).foregroundColor(p.ink)
                        .accessibilityIdentifier("newLabel-" + prov.rawValue)
                    SecureField("Paste the key", text: $newKey).autocorrectionDisabled().textInputAutocapitalization(.never)
                        .padding(10).background(p.chip).clipShape(RoundedRectangle(cornerRadius: 10)).foregroundColor(p.ink)
                        .accessibilityIdentifier("newKey-" + prov.rawValue)
                    HStack(spacing: 8) {
                        Button("Save account") {
                            if conns.add(provider: prov, label: newLabel, key: newKey) != nil { adding = false; newKey = ""; newLabel = "" }
                        }.buttonStyle(SoftButton()).accessibilityIdentifier("saveNew-" + prov.rawValue)
                        Button("Cancel") { adding = false; newKey = "" }.buttonStyle(SoftButton()).accessibilityIdentifier("cancelNew-" + prov.rawValue)
                    }
                }
            } else {
                Button("Add another account") { adding = true; newLabel = conns.nextDefaultLabel(prov); newKey = "" }
                    .buttonStyle(SoftButton()).accessibilityIdentifier("addAccount-" + prov.rawValue)
            }
        }
    }

    func commit(_ a: AIAccount) {
        if let l = labels[a.id], !l.trimmingCharacters(in: .whitespaces).isEmpty { conns.rename(a, to: l) }
        labels[a.id] = nil
    }

    func extra(_ a: AIAccount) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(a.label).font(.body.weight(.semibold)).foregroundColor(p.ink)
                Spacer()
                Text(conns.status(a)).font(.caption.bold()).foregroundColor(p.ink).accessibilityIdentifier("status-" + a.id)
            }
            TextField("Name in rooms", text: Binding(get: { labels[a.id] ?? a.label }, set: { labels[a.id] = $0 }))
                .autocorrectionDisabled().padding(10).background(p.card).clipShape(RoundedRectangle(cornerRadius: 10)).foregroundColor(p.ink)
                .onSubmit { commit(a) }.accessibilityIdentifier("label-" + a.id)
            SecureField(conns.hasKey(a) ? "A key is saved. Paste a new one to replace it." : "Paste your key", text: Binding(get: { drafts[a.id] ?? "" }, set: { drafts[a.id] = $0 }))
                .autocorrectionDisabled().textInputAutocapitalization(.never)
                .padding(10).background(p.card).clipShape(RoundedRectangle(cornerRadius: 10)).foregroundColor(p.ink)
                .accessibilityIdentifier("keyField-" + a.id)
            HStack(spacing: 8) {
                Button("Save") {
                    commit(a)
                    let k = drafts[a.id] ?? ""
                    if !k.isEmpty { _ = conns.save(k, for: a) }
                    drafts[a.id] = ""
                }.buttonStyle(SoftButton()).accessibilityIdentifier("saveKey-" + a.id)
                Button("Test") { Task { await conns.test(a) } }.buttonStyle(SoftButton()).accessibilityIdentifier("testKey-" + a.id)
                Button("Remove") { conns.remove(a) }.buttonStyle(SoftButton()).accessibilityIdentifier("removeKey-" + a.id)
            }
        }.padding(10).background(p.chip).clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

/// A coloured AI row. Tap it and its steps open under it. Only one is open at a time.
struct AITile: View {
    let prov: AIProvider
    @Binding var openId: String?
    @Environment(\.palette) var p
    @ObservedObject var conns = AIConnections.shared
    var open: Bool { openId == prov.rawValue }
    var main: AIAccount { conns.account(prov.rawValue) ?? AIAccount(id: prov.rawValue, provider: prov.rawValue, label: prov.name) }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .trailing) {
                Button { withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) { openId = open ? nil : prov.rawValue } } label: {
                    HStack(spacing: 12) {
                        IconTile(icon: prov.icon, color: prov.tint)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(prov.name).font(.system(.headline, design: .rounded)).foregroundColor(p.ink)
                            Text(prov.blurb).font(.caption).foregroundColor(p.soft)
                        }
                        Spacer(minLength: 120)
                    }
                    .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                    .background(p.card).clipShape(RoundedRectangle(cornerRadius: 22))
                    .overlay(RoundedRectangle(cornerRadius: 22).stroke(open ? prov.tint : Color.clear, lineWidth: 2))
                    .shadow(color: Color.loam.opacity(p.isDark ? 0 : 0.07), radius: 10, y: 5)
                }.buttonStyle(.plain).accessibilityIdentifier("ai-" + prov.rawValue)
                HStack(spacing: 8) {
                    Text(conns.status(main)).font(.system(size: 11, weight: .bold, design: .rounded)).lineLimit(1)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(conns.isConnected(main) ? Color.sprout : p.chip).foregroundColor(conns.isConnected(main) ? .loam : p.ink)
                        .clipShape(Capsule()).frame(maxWidth: 110)
                        .accessibilityIdentifier("status-" + main.id)
                    Image(systemName: "chevron.down").font(.system(size: 13, weight: .bold)).foregroundColor(prov.tint)
                        .rotationEffect(.degrees(open ? 180 : 0))
                }.padding(.trailing, 14).allowsHitTesting(false)
            }
            if open { ProviderPanel(prov: prov).transition(.opacity.combined(with: .move(edge: .top))) }
        }
    }
}

/// Pip's setup walk: pick an AI, get a key, paste, test, then learn how AIs wake each other. Skip any time.
struct SetupWizard: View {
    var onClose: () -> Void
    @Environment(\.palette) var p
    @Environment(\.openURL) var openURL
    @ObservedObject var conns = AIConnections.shared
    @State var page = 0
    @State var prov: AIProvider = .gemini
    @State var key = ""
    @State var state = "idle"   // idle, working, ok, fail
    @State var line = ""
    @State var bounce = false
    let total = 5

    var main: AIAccount { conns.account(prov.rawValue) ?? AIAccount(id: prov.rawValue, provider: prov.rawValue, label: prov.name) }

    var body: some View {
        ZStack {
            p.bg.ignoresSafeArea()
            LinearGradient(colors: [prov.tint.opacity(0.18), .clear], startPoint: .top, endPoint: .center).ignoresSafeArea()
            VStack(spacing: 14) {
                HStack {
                    StepDots(count: total, current: page, color: prov.tint)
                    Spacer()
                    Button("Skip setup", action: onClose).font(.subheadline.bold()).foregroundColor(p.soft).accessibilityIdentifier("wizSkip")
                }
                ScrollView {
                    VStack(spacing: 16) {
                        switch page {
                        case 0: welcome
                        case 1: pick
                        case 2: getKey
                        case 3: paste
                        default: wake
                        }
                    }.frame(maxWidth: .infinity).padding(.vertical, 8)
                }
            }.padding(18)
        }
        .onAppear { bounce = true }
    }

    var pip: some View {
        PipArt(pose: page == 4 ? .celebrate : .welcome, height: 120)
            .offset(y: bounce ? -6 : 6).animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: bounce)
    }

    func go(_ n: Int) { withAnimation(.easeInOut(duration: 0.25)) { page = n } }

    var welcome: some View {
        VStack(spacing: 14) {
            pip
            Text("Let's wake up your AI team!").font(.system(.title, design: .rounded).weight(.heavy)).multilineTextAlignment(.center).foregroundColor(p.ink)
            Text("I'll help you connect your first AI. It takes about a minute. One small step at a time.").multilineTextAlignment(.center).foregroundColor(p.soft)
            HStack(spacing: 10) { ForEach([AIProvider.claude, .chatgpt, .gemini, .groq], id: \.self) { IconTile(icon: $0.icon, color: $0.tint, size: 48) } }
            Button("Let's go") { go(1) }.buttonStyle(PrimaryButton()).accessibilityIdentifier("wizStart")
        }
    }

    var pick: some View {
        VStack(spacing: 14) {
            PipSays(text: "Which AI do you want first? Gemini and Groq have free keys.")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(AIProvider.allCases) { a in
                    Button { prov = a; key = ""; state = "idle"; line = ""; go(2) } label: {
                        VStack(spacing: 8) {
                            IconTile(icon: a.icon, color: a.tint, size: 52)
                            Text(a.name).font(.system(.subheadline, design: .rounded).weight(.bold)).foregroundColor(p.ink)
                            Text(a.blurb).font(.caption2).foregroundColor(p.soft)
                        }.frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(p.card).clipShape(RoundedRectangle(cornerRadius: 20))
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(a.tint.opacity(0.4), lineWidth: 1.5))
                    }.buttonStyle(.plain).accessibilityIdentifier("wizPick-" + a.rawValue)
                }
            }
        }
    }

    var getKey: some View {
        VStack(spacing: 14) {
            IconTile(icon: prov.icon, color: prov.tint, size: 72)
            Text("Get your \(prov.name) key").font(.system(.title2, design: .rounded).weight(.heavy)).foregroundColor(p.ink)
            PipSays(text: "A key is a password for the AI. Make one, copy it, then come back.", pose: .point)
            VStack(alignment: .leading, spacing: 10) {
                row("1.circle.fill", "Sign in at \(prov.company)")
                row("2.circle.fill", "Tap Create key")
                row("3.circle.fill", "Copy it")
            }.frame(maxWidth: .infinity, alignment: .leading).padding(14).background(p.card).clipShape(RoundedRectangle(cornerRadius: 20))
            Button { if let u = URL(string: prov.keyPage) { openURL(u) } } label: { Label("Open the key page", systemImage: "arrow.up.right.square.fill") }
                .buttonStyle(PrimaryButton()).accessibilityIdentifier("wizOpenKey")
            Button("I have my key") { go(3) }.buttonStyle(SoftButton()).accessibilityIdentifier("wizHaveKey")
            Button("Pick a different AI") { go(1) }.font(.subheadline.bold()).foregroundColor(p.soft)
        }
    }

    func row(_ icon: String, _ t: String) -> some View {
        HStack(spacing: 10) { Image(systemName: icon).foregroundColor(prov.tint).font(.title3); Text(t).foregroundColor(p.ink) }
    }

    var paste: some View {
        VStack(spacing: 14) {
            IconTile(icon: prov.icon, color: prov.tint, size: 72)
            Text("Paste your key").font(.system(.title2, design: .rounded).weight(.heavy)).foregroundColor(p.ink)
            PipSays(text: state == "ok" ? "You did it! \(prov.name) is awake." : "Paste it below. It stays on this phone only.", pose: state == "ok" ? .celebrate : .point)
            SecureField("Paste your key", text: $key).autocorrectionDisabled().textInputAutocapitalization(.never)
                .padding(14).background(p.card).clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(prov.tint.opacity(0.5), lineWidth: 1.5))
                .foregroundColor(p.ink).accessibilityIdentifier("wizKey")
            if state != "ok" {
                Button { Task { await connect() } } label: { Label(state == "working" ? "Connecting..." : "Connect it", systemImage: "bolt.fill") }
                    .buttonStyle(PrimaryButton()).disabled(state == "working" || key.trimmingCharacters(in: .whitespaces).isEmpty).accessibilityIdentifier("wizConnect")
            }
            if state == "working" { ProgressView() }
            if !line.isEmpty { Text(line).font(.subheadline.weight(.semibold)).foregroundColor(state == "ok" ? p.ink : .red).multilineTextAlignment(.center) }
            if state == "ok" {
                Button("Next: how AIs wake each other") { go(4) }.buttonStyle(PrimaryButton()).accessibilityIdentifier("wizNext")
                Button("Add another AI first") { go(1) }.buttonStyle(SoftButton()).accessibilityIdentifier("wizAnother")
            }
        }
    }

    var wake: some View {
        VStack(spacing: 14) {
            pip
            Text("How AIs wake each other").font(.system(.title2, design: .rounded).weight(.heavy)).foregroundColor(p.ink)
            WakeStory().padding(14).background(p.card).clipShape(RoundedRectangle(cornerRadius: 20))
            Button("Done, take me in") { onClose() }.buttonStyle(PrimaryButton()).accessibilityIdentifier("wizDone")
        }
    }

    func connect() async {
        let k = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard conns.save(k, for: main) else { state = "fail"; line = "Could not save the key."; return }
        state = "working"; line = ""
        await conns.test(main)
        key = ""
        if conns.isConnected(main) { state = "ok"; line = "Connected!" } else { state = "fail"; line = conns.status(main) }
    }
}
