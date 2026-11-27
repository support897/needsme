import SwiftUI

struct ProjectView: View {
    let name: String
    @EnvironmentObject var store: Store
    @Environment(\.palette) var p
    @State private var seg = 0
    var projectNeeds: [NeedItem] {
        let roomIds = Set(store.rooms.filter { $0.project == name }.map { $0.id })
        return store.needs.filter { $0.status == "open" && roomIds.contains($0.roomId) }
    }
    var projectRooms: [RoomItem] { store.rooms.filter { $0.project == name } }
    var tasksHere: [TaskItem] { store.tasks.filter { $0.area == name } }
    var aiNames: [String] {
        var seen: [String] = []
        for t in tasksHere { for n in [t.sourceBy, t.doneBy] where !n.isEmpty && n != "user" && !seen.contains(n) { seen.append(n) } }
        for n in projectNeeds where !seen.contains(n.ai) { seen.append(n.ai) }
        return seen
    }

    func who(_ t: TaskItem) -> String { t.doneBy.isEmpty || t.doneBy == "user" ? t.sourceBy : t.doneBy }

    @State private var asking: TaskItem?
    func taskRow(_ t: TaskItem) -> some View {
        HStack(spacing: 8) {
            LookRow(lead: { Button { store.toggle(t) } label: { CheckCircle(on: t.isDone, working: !t.isDone && !t.sourceRoom.isEmpty) }.buttonStyle(.plain) }, title: t.title,
                    sub: t.stamp.isEmpty ? (t.isDone ? "Done" : "") : t.stamp,
                    trail: { if !who(t).isEmpty { AIFace(label: who(t), size: 34) } })
            if !t.isDone {
                Button { asking = t } label: { Text("Ask AI").font(.system(size: 12, weight: .bold)).padding(.horizontal, 10).padding(.vertical, 7)
                    .background(Color.loam).foregroundColor(.sprout).clipShape(Capsule()) }.buttonStyle(.plain).accessibilityIdentifier("ask-" + t.title)
            }
        }
    }

    var body: some View {
        let pr = store.progress(name)
        let prog = pr.total > 0 ? Double(pr.done) / Double(pr.total) : 0
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 14) {
                    RoundedRectangle(cornerRadius: 17).fill(ProjectColor.color(name)).frame(width: 58, height: 58)
                        .overlay(Image(systemName: "rectangle.on.rectangle").font(.system(size: 26, weight: .medium)).foregroundColor(.loam))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("PROJECT").font(.system(size: 11, weight: .bold)).tracking(1.1).foregroundColor(.faint)
                        Text(name).font(.system(size: 22, weight: .bold)).foregroundColor(.loam)
                    }
                    Spacer()
                }
                HStack(spacing: 16) {
                    RingGauge(progress: prog, size: 100, line: 12) {
                        VStack(spacing: 0) {
                            Text("\(pr.done)/\(pr.total)").font(.system(size: 22, weight: .bold)).foregroundColor(.loam)
                            Text("done").font(.system(size: 12)).foregroundColor(.muted)
                        }
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(pr.done) of \(pr.total) tasks done").font(.system(size: 16, weight: .bold)).foregroundColor(.loam)
                        if let pct = store.percentDone(name) {
                            Text("\(pct)% done, counted from this project's tasks").font(.system(size: 12)).foregroundColor(.muted)
                        } else {
                            Text("Progress not yet measurable. This project has no tasks yet.").font(.system(size: 12)).foregroundColor(.muted)
                        }
                        if !aiNames.isEmpty {
                            HStack(spacing: 8) {
                                FaceStack(labels: aiNames, size: 28)
                                Text(aiNames.count == 1 ? "1 AI on it" : "\(aiNames.count) AIs on it").font(.system(size: 12)).foregroundColor(.muted)
                            }
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(16)
                .background(LinearGradient(colors: [.sproutPale, .cardTone], startPoint: .topLeading, endPoint: .bottomTrailing))
                .clipShape(RoundedRectangle(cornerRadius: 24)).shadow(color: Color.loam.opacity(0.07), radius: 12, y: 6)
                ProjectAIPanel(project: name)
                PillTabs(items: ["All tasks", "Recent", "Done"], selection: $seg)
                if seg == 0 {
                    if !projectNeeds.isEmpty {
                        SectionLabel(text: "Needs you (\(projectNeeds.count))")
                        ForEach(projectNeeds) { n in
                            LookRow(needs: true, lead: { CheckCircle(on: false, working: true) }, title: n.text, sub: "\(n.ai) needs you",
                                    trail: { HStack(spacing: 8) {
                                        AIFace(label: n.ai, size: 34, state: .needs)
                                        Button("Done") { store.resolveNeed(n) }.font(.system(size: 12, weight: .bold)).padding(.horizontal, 10).padding(.vertical, 6)
                                            .background(Color.loam).foregroundColor(.bone).clipShape(Capsule())
                                    } })
                        }
                    }
                    let open = tasksHere.filter { !$0.isDone }
                    if !open.isEmpty {
                        SectionLabel(text: "In motion (\(open.count))")
                        ForEach(open) { t in taskRow(t) }
                    }
                    let done = tasksHere.filter { $0.isDone }
                    if !done.isEmpty {
                        SectionLabel(text: "Done (\(done.count))")
                        ForEach(done) { t in taskRow(t) }
                    }
                    if tasksHere.isEmpty { Text("No tasks in this project yet.").foregroundColor(.muted) }
                } else if seg == 1 {
                    let recent = Array(tasksHere.sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }.prefix(5))
                    if recent.isEmpty { Text("No tasks in this project yet.").foregroundColor(.muted) }
                    ForEach(recent) { t in taskRow(t) }
                } else {
                    let done = tasksHere.filter { $0.isDone }
                    if done.isEmpty { Text("Nothing done in this project yet.").foregroundColor(.muted) }
                    ForEach(done) { t in taskRow(t) }
                }
                if !projectRooms.isEmpty {
                    SectionLabel(text: "Rooms")
                    ForEach(projectRooms) { r in
                        NavigationLink { RoomView(room: r, store: store) } label: {
                            LookRow(lead: { Image(systemName: "bubble.left.and.bubble.right").foregroundColor(.loam).frame(width: 26) }, title: r.title, trail: { Image(systemName: "chevron.right").foregroundColor(.faint) })
                        }.buttonStyle(.plain)
                    }
                }
                let ns = store.notes.filter { $0.projects.contains(name) && !$0.archived }
                SectionLabel(text: "Notes and prompts")
                if ns.isEmpty { Text("No notes in this project yet.").foregroundColor(.muted) }
                ForEach(ns) { n in
                    LookRow(lead: { Image(systemName: "doc.text").foregroundColor(.loam).frame(width: 26) }, title: n.title, sub: n.isPrompt ? "Prompt for \(n.ai)" : "Note", trail: { EmptyView() })
                }
            }.padding(.horizontal, 18).padding(.bottom, 12)
        }
        .lookBg()
        .navigationTitle(name).navigationBarTitleDisplayMode(.inline)
        .sheet(item: $asking) { AskAISheet(task: $0, project: name).environmentObject(store).environment(\.palette, p) }
    }
}

struct InboxView: View {
    @EnvironmentObject var store: Store
    @Environment(\.palette) var p
    var overdue: [TaskItem] { store.tasks.filter { $0.isOverdue } }
    var unsorted: [NoteItem] { store.notes.filter { $0.projects.isEmpty && !$0.archived } }
    var openNeeds: [NeedItem] { store.needs.filter { $0.status == "open" } }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if overdue.isEmpty && unsorted.isEmpty && openNeeds.isEmpty {
                    Card {
                        HStack(spacing: 12) {
                            PipImage(size: 48)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Inbox is empty").font(.headline).foregroundColor(p.ink)
                                Text("When an AI needs you, or something is late, it shows up here.").font(.subheadline).foregroundColor(p.soft)
                            }
                        }
                    }
                }
                ForEach(openNeeds) { n in
                    Card {
                        Text("\(n.ai) needs you").font(.headline).foregroundColor(p.ink)
                        Text(n.text).font(.subheadline).foregroundColor(p.ink)
                        Button("Done") { store.resolveNeed(n) }.buttonStyle(SoftButton()).frame(maxWidth: 140)
                    }.accessibilityIdentifier("need-" + n.id)
                }
                ForEach(overdue) { t in
                    Card {
                        Text("Overdue: \(t.title)").font(.headline).foregroundColor(p.ink)
                        Text("Due \(t.dueOn)").font(.caption).foregroundColor(p.soft)
                    }
                }
                ForEach(unsorted) { n in
                    Card {
                        Text("Needs a project: \(n.title)").font(.headline).foregroundColor(p.ink)
                        Text("Open Notes and pick a project for it.").font(.caption).foregroundColor(p.soft)
                    }
                }
            }.padding()
        }
        .lookBg()
        .hidesTabBar().navigationTitle("Inbox").navigationBarTitleDisplayMode(.inline)
    }
}
