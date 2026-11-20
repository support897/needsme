import SwiftUI
import FirebaseAuth

/// The AI kindness rainbow: how many people joined, who they are, and the giving link.
/// Counts and names come from the link service (/kindness). Giving itself happens on the
/// owner's website in the browser. The app never takes card details.
@MainActor final class KindnessStore: ObservableObject {
    static let shared = KindnessStore()
    struct Person: Identifiable, Decodable, Equatable {
        let id: String; let name: String; let msg: String; let gift: Bool; let t: Double; let ref: String?
    }
    private struct Reply: Decodable { let count: Int; let goal: Int?; let people: [Person]; let giveUrl: String?; let giveOn: Bool? }
    @Published var count = 0
    @Published var goal = 25000
    @Published var people: [Person] = []
    @Published var giveUrl = ""
    @Published var giveOn = false
    @Published var loaded = false

    var device: String {
        if let d = UserDefaults.standard.string(forKey: "nm_kind_device") { return d }
        let n = UUID().uuidString
        UserDefaults.standard.set(n, forKey: "nm_kind_device")
        return n
    }
    var joined: Bool { UserDefaults.standard.bool(forKey: "nm_kind_joined") }

    func refresh() async {
        guard let url = URL(string: BridgeCard.base + "/kindness") else { return }
        var r = URLRequest(url: url); r.timeoutInterval = 15
        guard let (d, resp) = try? await URLSession.shared.data(for: r), (resp as? HTTPURLResponse)?.statusCode == 200,
              let x = try? JSONDecoder().decode(Reply.self, from: d) else { return }
        count = x.count; goal = max(x.goal ?? 25000, x.count + 1); people = x.people
        giveUrl = x.giveUrl ?? ""; giveOn = x.giveOn ?? false; loaded = true
    }

    /// Joins for free. Returns nil when it worked, else a short reason.
    func join(name: String, msg: String, anon: Bool) async -> String? {
        guard let url = URL(string: BridgeCard.base + "/kindness/join") else { return "Try again." }
        var r = URLRequest(url: url); r.httpMethod = "POST"; r.timeoutInterval = 20
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let u = Auth.auth().currentUser, let t = try? await u.getIDToken() { r.setValue("Bearer " + t, forHTTPHeaderField: "Authorization") }
        r.httpBody = try? JSONSerialization.data(withJSONObject: ["name": name, "msg": msg, "anon": anon, "device": device] as [String: Any])
        guard let (d, resp) = try? await URLSession.shared.data(for: r) else { return "No connection. Try again." }
        if (resp as? HTTPURLResponse)?.statusCode == 200 {
            UserDefaults.standard.set(true, forKey: "nm_kind_joined")
            await refresh()
            return nil
        }
        let obj = try? JSONSerialization.jsonObject(with: d)
        return ((obj as? [String: Any])?["error"] as? String) ?? "Could not join. Try again."
    }

    /// The owner's giving page, with the amount and the name choices already filled in.
    func giveLink(amount: Int, name: String, msg: String, anon: Bool, ref: String) -> URL? {
        guard !giveUrl.isEmpty, var c = URLComponents(string: giveUrl), c.scheme == "https" else { return nil }
        var q = c.queryItems ?? []
        q.append(URLQueryItem(name: "amount", value: String(amount)))
        if anon { q.append(URLQueryItem(name: "name", value: "heart")) }
        else if !name.isEmpty { q.append(URLQueryItem(name: "display", value: name)) }
        if !msg.isEmpty { q.append(URLQueryItem(name: "msg", value: msg)) }
        q.append(URLQueryItem(name: "ref", value: ref))
        q.append(URLQueryItem(name: "from", value: "ios"))
        c.queryItems = q
        return c.url
    }
}

let rainbowBands: [UInt32] = [0xFF5E5E, 0xFF9F43, 0xFFD93D, 0x4CD964, 0x4D96FF, 0x7B61FF, 0xFF6BAE]

/// Seven glowing bands. `fill` (0 to 1) is how much of the rainbow is lit.
struct RainbowArc: View {
    let fill: CGFloat
    var body: some View {
        ZStack(alignment: .bottom) {
            ForEach(0..<7, id: \.self) { i in
                let d = 300 - CGFloat(i) * 30
                let c = Color(hex: rainbowBands[i])
                ZStack {
                    Circle().trim(from: 0.5, to: 1.0)
                        .stroke(Color.white.opacity(0.14), style: StrokeStyle(lineWidth: 15, lineCap: .round))
                    Circle().trim(from: 0.5, to: 0.5 + 0.5 * max(0.02, fill))
                        .stroke(c.opacity(0.55), style: StrokeStyle(lineWidth: 22, lineCap: .round)).blur(radius: 9)
                    Circle().trim(from: 0.5, to: 0.5 + 0.5 * max(0.02, fill))
                        .stroke(LinearGradient(colors: [c, c.opacity(0.78)], startPoint: .leading, endPoint: .trailing), style: StrokeStyle(lineWidth: 15, lineCap: .round))
                }
                .frame(width: d, height: d)
                .offset(y: d / 2)
            }
        }
        .frame(width: 300, height: 156, alignment: .bottom).clipped()
    }
}

struct Twinkles: View {
    @State private var on = false
    var body: some View {
        GeometryReader { g in
            ForEach(0..<26, id: \.self) { i in
                let fx = CGFloat((i * 37) % 100) / 100, fy = CGFloat((i * 53 + 11) % 100) / 100
                Image(systemName: i % 4 == 0 ? "sparkle" : "circle.fill")
                    .font(.system(size: i % 4 == 0 ? 11 : 3)).foregroundColor(.white)
                    .opacity(on ? (i % 2 == 0 ? 0.95 : 0.25) : (i % 2 == 0 ? 0.25 : 0.95))
                    .position(x: fx * g.size.width, y: fy * g.size.height * 0.8)
            }
        }
        .onAppear { withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) { on = true } }
        .allowsHitTesting(false).accessibilityHidden(true)
    }
}

struct KindnessView: View {
    @State private var reporting: KindnessStore.Person?
    @Environment(\.palette) var p
    @Environment(\.openURL) var openURL
    @Environment(\.scenePhase) var scene
    @EnvironmentObject var store: Store
    @ObservedObject private var k = KindnessStore.shared
    @State private var shown = 0
    @State private var fill: CGFloat = 0
    @State private var showPeople = false
    @State private var name = ""
    @State private var msg = ""
    @State private var anon = false
    @State private var amount = 10
    @State private var burstName: String? = nil
    @State private var error = ""
    @State private var busy = false
    @State private var ref = UUID().uuidString.lowercased()
    @State private var waitingGift = false
    @State private var tick = 0
    private let timer = Timer.publish(every: 2.6, on: .main, in: .common).autoconnect()

    var carousel: String {
        guard !k.people.isEmpty else { return "Be the first name in the rainbow" }
        let x = k.people[tick % k.people.count]
        return x.name
    }

    var hero: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 34)
                .fill(LinearGradient(colors: [Color(hex: 0x1B1F4B), Color(hex: 0x5B3FA0), Color(hex: 0xE87AA6), Color(hex: 0xFFC9A0)], startPoint: .top, endPoint: .bottom))
            Twinkles()
            VStack(spacing: 8) {
                Text("NEEDSME AI").font(.system(size: 12, weight: .heavy)).tracking(2.6).foregroundColor(.white.opacity(0.85))
                Text("Join the AI kindness revolution")
                    .font(.system(size: 27, weight: .black, design: .rounded)).foregroundColor(.white).multilineTextAlignment(.center)
                ZStack(alignment: .bottom) {
                    RainbowArc(fill: fill)
                    VStack(spacing: 2) {
                        Image(systemName: "heart.fill").font(.system(size: 14)).foregroundColor(Color(hex: 0xFF6BAE))
                        Text(carousel).font(.system(size: 13, weight: .bold, design: .rounded)).foregroundColor(.white)
                            .lineLimit(1).frame(width: 110).id(carousel + String(tick))
                            .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    }.padding(.bottom, 6)
                }
                .onTapGesture { showPeople = true }
                .accessibilityElement(children: .ignore).accessibilityLabel("The rainbow. Tap to see everyone in it.")
                .accessibilityAddTraits(.isButton).accessibilityIdentifier("rainbow")
                Text(shown.formatted()).font(.system(size: 52, weight: .black, design: .rounded)).foregroundColor(.white)
                    .contentTransition(.numericText()).accessibilityIdentifier("kindCount")
                Text("have joined AI kindness").font(.system(size: 16, weight: .bold, design: .rounded)).foregroundColor(.white.opacity(0.92))
                    .accessibilityIdentifier("kindHumans")
                Text("Tap the rainbow to see everyone").font(.caption).foregroundColor(.white.opacity(0.7))
            }.padding(.vertical, 26).padding(.horizontal, 14)
        }
        .shadow(color: Color(hex: 0x5B3FA0).opacity(0.35), radius: 18, y: 10)
    }

    var ideals: some View {
        Card {
            Text("What we believe").font(.system(.title3, design: .rounded).bold()).foregroundColor(p.ink)
            ideal("heart.fill", 0xFF6BAE, "Be kind to your AI", "How we talk to AI shapes how we talk to each other. Say please. Say thanks.")
            ideal("hands.sparkles.fill", 0xFF9F43, "AI should help people", "Tools that serve you first. Not ads, not tricks, not your data.")
            ideal("person.3.fill", 0x4CD964, "Free for the next person", "Every gift keeps NeedsMe free for someone who could not pay.")
            ideal("lock.shield.fill", 0x4D96FF, "Your stuff stays yours", "No ads. No tracking. Your AI keys stay on your phone.")
        }
    }
    func ideal(_ icon: String, _ hex: UInt32, _ t: String, _ s: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).foregroundColor(.white).frame(width: 34, height: 34).background(Color(hex: hex)).clipShape(RoundedRectangle(cornerRadius: 11))
            VStack(alignment: .leading, spacing: 2) {
                Text(t).font(.system(.subheadline, design: .rounded).bold()).foregroundColor(p.ink)
                Text(s).font(.footnote).foregroundColor(p.soft)
            }
        }
    }

    var joinCard: some View {
        Card {
            Text("Put your name in the rainbow").font(.system(.title3, design: .rounded).bold()).foregroundColor(p.ink)
            Text("Free. Choose how you show up.").font(.subheadline).foregroundColor(p.soft)
            TextField("Your name", text: $name).textFieldStyle(.roundedBorder).disabled(anon).opacity(anon ? 0.4 : 1)
                .accessibilityIdentifier("kindName")
            Toggle("Stay anonymous", isOn: $anon).tint(.sprout).accessibilityIdentifier("kindAnon")
            TextField("A kind message (optional)", text: $msg, axis: .vertical).lineLimit(1...3).textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("kindMsg")
            if k.joined {
                Label("You are in the rainbow. Thank you.", systemImage: "checkmark.seal.fill").font(.subheadline.bold()).foregroundColor(.sproutDeep)
                    .accessibilityIdentifier("kindJoined")
            } else {
                Button(busy ? "Joining..." : "Join the revolution (free)") { Task { await join() } }
                    .buttonStyle(PrimaryButton()).disabled(busy).accessibilityIdentifier("kindJoin")
            }
            if !error.isEmpty { Text(error).font(.footnote).foregroundColor(.red) }
        }
    }

    var giveCard: some View {
        Card {
            Text("Give to keep it free").font(.system(.title3, design: .rounded).bold()).foregroundColor(p.ink)
            Text("Your name, message and choice above go with your gift. Pay with Apple Pay, Google Pay, PayPal and more on our giving page.")
                .font(.subheadline).foregroundColor(p.soft)
            HStack(spacing: 8) {
                ForEach([5, 10, 25, 50, 100], id: \.self) { a in
                    Button("$\(a)") { amount = a }
                        .font(.system(.subheadline, design: .rounded).bold()).frame(maxWidth: .infinity).padding(.vertical, 10)
                        .background(amount == a ? Color.loam : p.chip).foregroundColor(amount == a ? Color.bone : p.ink)
                        .clipShape(RoundedRectangle(cornerRadius: 14)).accessibilityIdentifier("amt-\(a)")
                }
            }
            Button(k.giveOn ? "Give $\(amount) in one tap" : "Giving opens soon") { give() }
                .buttonStyle(PrimaryButton()).disabled(!k.giveOn).accessibilityIdentifier("giveButton")
            Text("Opens our giving page in your browser. NeedsMe never takes card details in the app. Your amount is already chosen there.")
                .font(.caption).foregroundColor(p.soft).accessibilityIdentifier("giveNote")
        }
    }

    var wall: some View {
        Card {
            Text("The kindness wall").font(.system(.title3, design: .rounded).bold()).foregroundColor(p.ink).accessibilityIdentifier("kindnessWall")
            Text("Names and kind words from people who joined stay here.").font(.subheadline).foregroundColor(p.soft)
            let notes = k.people.filter { !$0.msg.isEmpty }.prefix(8)
            if notes.isEmpty { Text("No messages yet. Yours could be the first.").font(.subheadline).foregroundColor(p.ink) }
            ForEach(Array(notes)) { x in
                VStack(alignment: .leading, spacing: 2) {
                    Text("\"" + x.msg + "\"").font(.subheadline).foregroundColor(p.ink)
                    HStack(spacing: 4) {
                        if x.gift { Image(systemName: "heart.fill").font(.caption2).foregroundColor(Color(hex: 0xFF6BAE)) }
                        Text(x.name).font(.caption.bold()).foregroundColor(p.soft)
                    }
                }
                .contextMenu { Button { reporting = x } label: { Label("Report this entry", systemImage: "flag") } }
            }
        }
        .sheet(item: $reporting) { x in NavigationStack { ReportView(kind: .feedback, prefill: "Report kindness entry " + x.id + " (name: " + x.name + "). Why: ") } }
    }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    hero
                    joinCard
                    giveCard
                    ideals
                    wall
                }.padding()
            }
            if let n = burstName { RainbowBurst(name: n, count: k.count) { burstName = nil }.transition(.opacity) }
        }
        .hidesTabBar().lookBg().navigationTitle("AI Kindness").navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPeople) { RainbowPeopleSheet(people: k.people, count: k.count) }
        .onAppear {
            if name.isEmpty { name = store.savedName ?? "" }
            Task { await k.refresh(); settle() }
        }
        .onChange(of: k.count) { _ in settle() }
        .onChange(of: scene) { s in if s == .active && waitingGift { Task { await watchGift() } } }
        .onReceive(timer) { _ in withAnimation(.easeInOut(duration: 0.4)) { tick += 1 } }
    }

    /// The number counts up and the rainbow fills to where the people are.
    func settle() {
        let target = k.count, start = shown
        withAnimation(.easeOut(duration: 1.8)) { fill = min(1, CGFloat(k.count) / CGFloat(max(1, k.goal))) }
        Task {
            let steps = 36
            for i in 1...steps {
                try? await Task.sleep(nanoseconds: 40_000_000)
                withAnimation(.easeOut(duration: 0.12)) { shown = start + (target - start) * i / steps }
            }
            shown = target
        }
    }

    func join() async {
        error = ""; busy = true; defer { busy = false }
        if AIConsent.testMode { return }
        if let e = await k.join(name: name.trimmingCharacters(in: .whitespaces), msg: msg.trimmingCharacters(in: .whitespaces), anon: anon) { error = e; return }
        celebrate(anon ? "Someone kind" : (name.isEmpty ? "friend" : name))
    }

    func give() {
        guard let url = k.giveLink(amount: amount, name: name.trimmingCharacters(in: .whitespaces), msg: msg.trimmingCharacters(in: .whitespaces), anon: anon, ref: ref) else { return }
        waitingGift = true
        openURL(url)
    }

    func watchGift() async {
        for _ in 0..<30 {
            await k.refresh()
            if let me = k.people.first(where: { $0.ref == ref && $0.gift }) {
                waitingGift = false; ref = UUID().uuidString.lowercased()
                celebrate(me.name); return
            }
            try? await Task.sleep(nanoseconds: 4_000_000_000)
        }
        waitingGift = false
    }

    func celebrate(_ n: String) {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation(.easeInOut(duration: 0.3)) { burstName = n }
    }
}

/// The moment after joining or giving: confetti, a rainbow that sweeps in, and the name.
struct RainbowBurst: View {
    let name: String
    let count: Int
    let done: () -> Void
    @State private var go = false
    @State private var fill: CGFloat = 0
    private struct Piece { let dx: CGFloat; let dy: CGFloat; let rot: Double; let color: UInt32; let size: CGFloat }
    @State private var pieces: [Piece] = (0..<70).map { _ in
        Piece(dx: .random(in: -170...170), dy: .random(in: -420...(-40)), rot: .random(in: 0...540), color: rainbowBands.randomElement() ?? 0xFF5E5E, size: .random(in: 6...12))
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.62).ignoresSafeArea().onTapGesture { done() }
            ForEach(Array(pieces.enumerated()), id: \.offset) { _, c in
                RoundedRectangle(cornerRadius: 2).fill(Color(hex: c.color)).frame(width: c.size, height: c.size * 1.7)
                    .rotationEffect(.degrees(go ? c.rot : 0))
                    .offset(x: go ? c.dx : 0, y: go ? c.dy + 520 : 40)
                    .opacity(go ? 0 : 1)
            }
            VStack(spacing: 14) {
                RainbowArc(fill: fill).scaleEffect(1.05)
                Text("Welcome to the rainbow").font(.system(size: 15, weight: .heavy, design: .rounded)).tracking(1).foregroundColor(.white.opacity(0.85))
                Text(name).font(.system(size: 34, weight: .black, design: .rounded)).foregroundColor(.white).lineLimit(1).minimumScaleFactor(0.5)
                Text("You are one of \(count.formatted()) people choosing kindness.")
                    .font(.subheadline).foregroundColor(.white.opacity(0.9)).multilineTextAlignment(.center)
                Button("Keep the rainbow going") { done() }.buttonStyle(PrimaryButton()).frame(maxWidth: 260).padding(.top, 6)
                    .accessibilityIdentifier("burstDone")
            }.padding(24)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 2.2)) { go = true }
            withAnimation(.easeOut(duration: 1.6)) { fill = 1 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 9) { done() }
        }
    }
}

/// Everyone in the rainbow. Names stay here.
struct RainbowPeopleSheet: View {
    @State private var reporting: KindnessStore.Person?
    let people: [KindnessStore.Person]
    let count: Int
    @Environment(\.dismiss) var dismiss
    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("\(count.formatted()) people are in the rainbow")) {
                    if people.isEmpty { Text("No names yet. Yours could be the first.") }
                    ForEach(Array(people.enumerated()), id: \.element.id) { i, x in
                        HStack(alignment: .top, spacing: 12) {
                            Text(String(x.name.prefix(1)).uppercased()).font(.system(.subheadline, design: .rounded).bold()).foregroundColor(.white)
                                .frame(width: 34, height: 34).background(Color(hex: rainbowBands[i % 7])).clipShape(Circle())
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 4) {
                                    Text(x.name).font(.body.weight(.semibold))
                                    if x.gift { Image(systemName: "heart.fill").font(.caption).foregroundColor(Color(hex: 0xFF6BAE)) }
                                }
                                if !x.msg.isEmpty { Text(x.msg).font(.subheadline).foregroundColor(.secondary) }
                            }
                        }
                        .contextMenu { Button { reporting = x } label: { Label("Report this entry", systemImage: "flag") } }
                    }
                }
            }
            .accessibilityIdentifier("peopleList")
            .sheet(item: $reporting) { x in NavigationStack { ReportView(kind: .feedback, prefill: "Report kindness entry " + x.id + " (name: " + x.name + "). Why: ") } }
            .navigationTitle("The rainbow").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}
