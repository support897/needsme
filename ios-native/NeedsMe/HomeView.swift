import SwiftUI

/// Home, as approved: the one thing that needs you, drawn big with how close it is; what your AIs got done
/// this week; today's needs cleared as a ring; and the settle when a need is cleared.
struct HomeView: View {
    var goMore: () -> Void = {}
    @EnvironmentObject var store: Store
    @Environment(\.palette) var p
    @ObservedObject private var conns = AIConnections.shared
    @State private var seg = 0
    @State private var didPick = false
    @State private var clearedTitle: String?
    @State private var clearedAI = ""

    var openNeeds: [NeedItem] { store.needs.filter { $0.status == "open" } }
    var overdue: [TaskItem] { store.tasks.filter { $0.isOverdue } }
    var nextTask: TaskItem? { store.tasks.first { !$0.isDone } }
    var clearedCount: Int { store.needs.filter { $0.status != "open" }.count }
    var doneCount: Int { store.tasks.filter { $0.isDone }.count }

    func roomTitle(_ n: NeedItem) -> String { store.rooms.first { $0.id == n.roomId }?.title ?? "" }
    func projectOf(_ n: NeedItem) -> String { store.rooms.first { $0.id == n.roomId }?.project ?? "" }

    var greeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        let part = h < 12 ? "Good morning" : (h < 18 ? "Good afternoon" : "Good evening")
        return "\(part), \(store.greetingName)"
    }
    var weekday: String { let f = DateFormatter(); f.dateFormat = "EEEE"; return f.string(from: Date()) }

    // MARK: what the big card shows

    struct Hero { var title: String; var who: String; var line: String; var done: Int; var total: Int; var label: String; var chips: [String] }
    var hero: Hero? {
        if let n = openNeeds.first {
            let proj = projectOf(n)
            let pr = proj.isEmpty ? (done: 0, total: 0) : store.progress(proj)
            let chips = openNeeds.dropFirst().prefix(2).map { $0.text } + (overdue.prefix(1).map { $0.title })
            if pr.total > 0 {
                return Hero(title: n.text, who: n.ai, line: "\(n.ai) is waiting on your yes.", done: pr.done, total: pr.total, label: "steps ready", chips: Array(chips.prefix(2)))
            }
            return Hero(title: n.text, who: n.ai, line: "\(n.ai) is waiting on your yes.", done: clearedCount, total: clearedCount + openNeeds.count, label: "needs cleared", chips: Array(chips.prefix(2)))
        }
        if let t = overdue.first {
            let pr = t.area.isEmpty ? (done: doneCount, total: store.tasks.count) : store.progress(t.area)
            return Hero(title: t.title, who: "", line: "This one is overdue.", done: pr.done, total: pr.total, label: "tasks done", chips: [])
        }
        return nil
    }

    func clear(need n: NeedItem) {
        store.resolveNeed(n)
        settle(n.text, n.ai)
    }
    func clear(task t: TaskItem) {
        store.toggle(t)
        settle(t.title, "")
    }
    func settle(_ title: String, _ ai: String) {
        clearedAI = ai
        withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) { clearedTitle = title }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.4) { withAnimation(.easeInOut(duration: 0.3)) { clearedTitle = nil } }
    }

    // MARK: week of what got done

    var doneByDay: [(letter: String, you: Int, ai: Int, today: Bool)] {
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        let cal = Calendar.current
        let wf = DateFormatter(); wf.dateFormat = "EEEEE"
        return (0..<7).reversed().map { back in
            let d = cal.date(byAdding: .day, value: -back, to: Date()) ?? Date()
            let key = df.string(from: d)
            let ts = store.tasks.filter { $0.isDone && $0.doneDate == key }
            let ai = ts.filter { !$0.doneBy.isEmpty && $0.doneBy != "user" }.count
            let letter = Store.demo ? ["M", "T", "W", "T", "F", "S", "S"][6 - back] : wf.string(from: d)
            return (letter, ts.count - ai, ai, back == 0)
        }
    }
    var weekTotal: Int { doneByDay.reduce(0) { $0 + $1.you + $1.ai } }
    var movedProjects: Int {
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        let weekAgo = Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .day, value: -6, to: Date()) ?? Date())
        return Set(store.tasks.filter { t in
            guard t.isDone, !t.area.isEmpty, let d = df.date(from: t.doneDate) else { return false }
            return d >= weekAgo
        }.map { $0.area }).count
    }

    // MARK: body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    if let t = clearedTitle { clearedCard(t) } else { heroCard }
                    if clearedTitle != nil { risingNext }
                    PillTabs(items: ["Overview", "Needs you", "Done"], selection: $seg)
                    if seg == 0 || seg == 1 { overview }
                    if seg == 1 { needsList }
                    if seg == 2 { doneList }
                }.padding(.horizontal, 18).padding(.bottom, 12)
            }
            .lookBg()
            .toolbar(.hidden, for: .navigationBar)
            .onAppear { if !openNeeds.isEmpty && !didPick { seg = 1; didPick = true } }
        }
    }

    var header: some View {
        HStack(spacing: 10) {
            Button(action: goMore) { SproutMark(size: 38).clipShape(Circle()) }
                .accessibilityLabel("More").accessibilityIdentifier("tab-More")
            VStack(alignment: .leading, spacing: 1) {
                Text(weekday).font(.system(size: 12)).foregroundColor(.muted)
                Text(greeting).font(.system(size: 17, weight: .bold)).foregroundColor(.loam)
            }
            Spacer()
            NavigationLink { InboxView() } label: { HeaderIcon(system: "bell", dot: !openNeeds.isEmpty) }
                .accessibilityLabel("Inbox").accessibilityIdentifier("inboxButton")
        }.padding(.top, 8)
    }

    // MARK: the big card

    @ViewBuilder var heroCard: some View {
        if let h = hero {
            ZStack(alignment: .topTrailing) {
                PipArt(pose: .point, height: 108).padding(.top, 34).padding(.trailing, 2)
                VStack(alignment: .leading, spacing: 0) {
                    Text("THE ONE THING THAT NEEDS YOU").font(.system(size: 12, weight: .bold)).tracking(1).foregroundColor(.sproutDeep)
                        .frame(maxWidth: 190, alignment: .leading).fixedSize(horizontal: false, vertical: true)
                    Text(h.title).font(.system(size: 21, weight: .bold)).foregroundColor(.loam).lineLimit(3)
                        .frame(maxWidth: 205, alignment: .leading).padding(.top, 6).padding(.bottom, 10)
                        .contentShape(Rectangle())
                        .onTapGesture { if let n = openNeeds.first { clear(need: n) } else if let t = overdue.first { clear(task: t) } }
                        .accessibilityAddTraits(.isButton).accessibilityIdentifier("heroDone")
                    HStack(spacing: 8) {
                        if !h.who.isEmpty { AIFace(label: h.who, size: 24) }
                        Text(h.line).font(.system(size: 12.5, weight: .semibold)).foregroundColor(.loam)
                            .frame(maxWidth: 160, alignment: .leading).fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 4)
                    }.padding(.bottom, 12)
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(h.total > 0 ? "\(h.done)/\(h.total)" : "0/0").font(.system(size: 34, weight: .heavy)).foregroundColor(.loam)
                        Text(h.label).font(.system(size: 12.5, weight: .semibold)).foregroundColor(.sproutDeep)
                        Spacer()
                        Text(h.total > 0 ? "\(Int((Double(h.done) / Double(h.total) * 100).rounded()))%" : "0%")
                            .font(.system(size: 20, weight: .bold)).foregroundColor(.loam)
                    }
                    LookBar(progress: h.total > 0 ? Double(h.done) / Double(h.total) : 0).padding(.top, 8).padding(.bottom, 12)
                    if !h.chips.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(h.chips, id: \.self) { c in
                                    Text(c).font(.system(size: 12.5, weight: .semibold)).lineLimit(1).foregroundColor(.loam)
                                        .padding(.horizontal, 11).padding(.vertical, 8)
                                        .background(Color.cardTone.opacity(0.85)).clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                            }
                        }
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(18)
            .background(LinearGradient(colors: [.sproutMid, .sproutPale, .bone], startPoint: .topLeading, endPoint: .bottomTrailing))
            .clipShape(RoundedRectangle(cornerRadius: 28))
            .shadow(color: Color(red: 0.47, green: 0.55, blue: 0.24).opacity(0.25), radius: 15, y: 10)
            .accessibilityIdentifier("heroCard")
        } else {
            ZStack(alignment: .topTrailing) {
                PipArt(pose: .welcome, height: 100).padding(.top, 24)
                VStack(alignment: .leading, spacing: 6) {
                    Text("THE ONE THING THAT NEEDS YOU").font(.system(size: 12, weight: .bold)).tracking(1).foregroundColor(.sproutDeep)
                        .frame(maxWidth: 190, alignment: .leading).fixedSize(horizontal: false, vertical: true)
                    Text("All clear").font(.system(size: 26, weight: .bold)).foregroundColor(.loam).padding(.top, 4)
                    Text("Nothing needs you right now. Pip will tell you when something does.")
                        .font(.system(size: 13.5)).foregroundColor(.loam).frame(maxWidth: 200, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text("\(clearedCount)/\(clearedCount)").font(.system(size: 34, weight: .heavy)).foregroundColor(.loam)
                        Text("needs cleared").font(.system(size: 12.5, weight: .semibold)).foregroundColor(.sproutDeep)
                    }.padding(.top, 12)
                    LookBar(progress: clearedCount > 0 ? 1 : 0).padding(.top, 4)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(18)
            .background(LinearGradient(colors: [.sproutMid, .sproutPale, .bone], startPoint: .topLeading, endPoint: .bottomTrailing))
            .clipShape(RoundedRectangle(cornerRadius: 28))
            .shadow(color: Color(red: 0.47, green: 0.55, blue: 0.24).opacity(0.25), radius: 15, y: 10)
            .accessibilityIdentifier("heroCard")
        }
    }

    /// The settle: the card glows, the check lands, Pip cheers, the bar moves, the next need rises.
    func clearedCard(_ t: String) -> some View {
        let total = clearedCount + openNeeds.count
        let prog = total > 0 ? Double(clearedCount) / Double(total) : 1
        return VStack(spacing: 0) {
            PipArt(pose: .celebrate, height: 150)
            ZStack { Circle().fill(Color.loam); Image(systemName: "checkmark").font(.system(size: 26, weight: .heavy)).foregroundColor(.sprout) }
                .frame(width: 54, height: 54).shadow(color: Color.loam.opacity(0.3), radius: 10, y: 6).padding(.top, -2)
            Text("Cleared. \(t)").font(.system(size: 23, weight: .heavy)).foregroundColor(.loam).multilineTextAlignment(.center)
                .lineLimit(2).padding(.top, 10)
            Text(openNeeds.isEmpty ? "Nothing else needs you right now." : "The next one is rising.")
                .font(.system(size: 13.5, weight: .semibold)).foregroundColor(Color(hex: 0x2C3419)).padding(.top, 4)
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("\(clearedCount)/\(total)").font(.system(size: 34, weight: .heavy)).foregroundColor(.loam)
                Text("\(Int((prog * 100).rounded()))%").font(.system(size: 20, weight: .bold)).foregroundColor(.loam)
            }.padding(.top, 12)
            LookBar(progress: prog).padding(.top, 6)
        }
        .padding(20).frame(maxWidth: .infinity)
        .background(LinearGradient(colors: [.sprout, .sproutMid, Color(hex: 0xE8EDCB)], startPoint: .topLeading, endPoint: .bottomTrailing))
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .overlay(RoundedRectangle(cornerRadius: 28).stroke(Color.sprout.opacity(0.35), lineWidth: 6).padding(-3))
        .shadow(color: Color(red: 0.47, green: 0.55, blue: 0.24).opacity(0.4), radius: 20, y: 12)
        .transition(.scale(scale: 0.96).combined(with: .opacity))
        .accessibilityIdentifier("clearedCard")
    }

    @ViewBuilder var risingNext: some View {
        if let n = openNeeds.first {
            SectionLabel(text: "Rising next", trailing: "1 of \(openNeeds.count)")
            LookRow(needs: true, lead: { CheckCircle(on: false, working: true) }, title: n.text,
                    sub: [n.ai, roomTitle(n)].filter { !$0.isEmpty }.joined(separator: " · "),
                    trail: { AIFace(label: n.ai, size: 34, state: .needs) })
        }
        ringCard
        if let t = store.tasks.first(where: { $0.isDone && !$0.doneBy.isEmpty && $0.doneBy != "user" }) {
            SectionLabel(text: "New from your AIs")
            LookRow(lead: { CheckCircle(on: true) }, title: t.title, sub: "\(t.doneBy) · done",
                    trail: { AIFace(label: t.doneBy, size: 30, state: .done) })
        }
    }

    // MARK: the cards under it

    var ringCard: some View {
        let total = clearedCount + openNeeds.count + overdue.count
        let prog = total > 0 ? Double(clearedCount) / Double(total) : 0
        return HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Today's needs").font(.system(size: 15, weight: .bold)).foregroundColor(.loam)
                CountPill(text: "\(clearedCount)/\(total) cleared")
                Text(total == 0 ? "Nothing has needed you yet." : (openNeeds.isEmpty && overdue.isEmpty ? "All cleared. Nice one." : "\(clearedCount) cleared so far."))
                    .font(.system(size: 12)).foregroundColor(.muted)
            }
            Spacer()
            RingGauge(progress: prog, size: 92, line: 11) { Image(systemName: "checkmark").font(.system(size: 28, weight: .heavy)).foregroundColor(.loam) }
        }
        .padding(16).background(Color.cardTone).clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: Color.loam.opacity(0.07), radius: 12, y: 6)
        .accessibilityIdentifier("ringCard")
    }

    var weekCard: some View {
        let days = doneByDay
        let maxV = max(days.map { $0.you + $0.ai }.max() ?? 1, 1)
        return VStack(alignment: .leading, spacing: 10) {
            HStack { Text("What your AIs got done").font(.system(size: 15, weight: .bold)).foregroundColor(.loam); Spacer()
                Text("Last 7 days").font(.system(size: 12)).foregroundColor(.muted) }
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, d in
                    VStack(spacing: 6) {
                        let h = CGFloat(d.you + d.ai) / CGFloat(maxV) * 70
                        VStack(spacing: 0) {
                            Spacer(minLength: 0)
                            if d.you + d.ai == 0 {
                                Capsule().fill(Color.sproutPale).frame(width: 14, height: 8)
                            } else {
                                VStack(spacing: 0) {
                                    if d.you > 0 { Rectangle().fill(Color.sproutPale).frame(height: max(h * CGFloat(d.you) / CGFloat(d.you + d.ai), 7)) }
                                    if d.ai > 0 { Rectangle().fill(d.today ? Color.loam : Color.sprout).frame(height: max(h * CGFloat(d.ai) / CGFloat(d.you + d.ai), 7)) }
                                }.frame(width: 14).clipShape(Capsule())
                            }
                        }.frame(height: 74)
                        Text(d.letter).font(.system(size: 11, weight: d.today ? .heavy : .semibold)).foregroundColor(d.today ? .loam : .faint)
                    }.frame(maxWidth: .infinity)
                }
            }
            HStack(spacing: 16) {
                Text("\(weekTotal) things done").foregroundColor(.sproutDeep)
                Text(movedProjects == 1 ? "1 project moved" : "\(movedProjects) projects moved").foregroundColor(.loam)
            }.font(.system(size: 13, weight: .bold))
        }
        .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 12)
        .background(Color.cardTone).clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: Color.loam.opacity(0.07), radius: 12, y: 6)
        .accessibilityElement(children: .contain).accessibilityIdentifier("homeSummary")
    }

    @ViewBuilder var overview: some View {
        weekCard
        if clearedTitle == nil { ringCard }
        if !store.projects.isEmpty {
            SectionLabel(text: "Projects")
            ForEach(store.projects, id: \.self) { name in
                let pr = store.progress(name)
                NavigationLink { ProjectView(name: name) } label: { ProjectCardLook(name: name, done: pr.done, total: pr.total) }
                    .buttonStyle(.plain).accessibilityIdentifier("project-\(name)")
            }
        }
    }

    @ViewBuilder var needsList: some View {
        if openNeeds.isEmpty && overdue.isEmpty {
            LookRow(lead: { PipArt(pose: .welcome, height: 40) }, title: "All clear", sub: "Nothing needs you right now.", trail: { EmptyView() })
        }
        ForEach(openNeeds) { n in
            LookRow(needs: true, lead: { CheckCircle(on: false, working: true) }, title: n.text,
                    sub: [n.ai, roomTitle(n)].filter { !$0.isEmpty }.joined(separator: " · "),
                    trail: { Button("Done") { clear(need: n) }.font(.system(size: 13, weight: .bold)).padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Color.loam).foregroundColor(.bone).clipShape(Capsule()).accessibilityIdentifier("homeNeedDone-" + n.id) })
        }
        ForEach(overdue) { t in
            LookRow(needs: true, lead: { CheckCircle(on: false, working: true) }, title: t.title, sub: "Overdue · due \(t.dueOn)", trail: { EmptyView() })
        }
    }

    @ViewBuilder var doneList: some View {
        let wins = Array(store.tasks.filter { $0.isDone }.prefix(4))
        let notes = Array(store.notes.filter { !$0.archived }.prefix(2))
        if wins.isEmpty && notes.isEmpty {
            LookRow(lead: { PipArt(pose: .welcome, height: 40) }, title: "Nothing yet", sub: "Your notes and finished tasks show up here.", trail: { EmptyView() })
        }
        ForEach(wins) { t in
            LookRow(lead: { CheckCircle(on: true) }, title: t.title, sub: t.area, trail: { EmptyView() })
        }
        ForEach(notes) { n in
            LookRow(lead: { Image(systemName: "doc.text").foregroundColor(.loam).frame(width: 26) }, title: n.title, sub: "Note", trail: { EmptyView() })
        }
    }
}

/// A project card: a colour tile on the left, the name, a progress bar and a small count pill.
struct ProjectCardLook: View {
    let name: String
    let done: Int
    let total: Int
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 17).fill(ProjectColor.color(name)).frame(width: 54, height: 54)
                .overlay(Image(systemName: "rectangle.on.rectangle").font(.system(size: 22, weight: .medium)).foregroundColor(.loam))
            VStack(alignment: .leading, spacing: 8) {
                Text("PROJECT").font(.system(size: 10.5, weight: .bold)).tracking(1.1).foregroundColor(.faint)
                Text(name).font(.system(size: 15.5, weight: .bold)).foregroundColor(.loam).multilineTextAlignment(.leading)
                if total > 0 {
                    HStack(spacing: 10) {
                        LookBar(progress: Double(done) / Double(total), tone: ProjectColor.color(name), height: 6)
                        CountPill(text: "\(done)/\(total)")
                    }
                } else {
                    Text("Progress not yet measurable").font(.system(size: 12)).foregroundColor(.muted)
                }
            }
        }
        .padding(13).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardTone).clipShape(RoundedRectangle(cornerRadius: 22))
        .shadow(color: Color.loam.opacity(0.06), radius: 10, y: 5)
    }
}
