import SwiftUI

struct TasksView: View {
    @EnvironmentObject var store: Store
    @Environment(\.palette) var p
    @State private var seg = 0
    @State private var searching = false
    @State private var query = ""

    /// AI work carries a room stamp; everything else is hers (HTML section 9 owner types).
    func isAIWork(_ t: TaskItem) -> Bool { !t.sourceRoom.isEmpty }
    func hit(_ t: TaskItem) -> Bool { query.isEmpty || t.title.localizedCaseInsensitiveContains(query) }
    var openNeeds: [NeedItem] { store.needs.filter { $0.status == "open" && (query.isEmpty || $0.text.localizedCaseInsensitiveContains(query)) } }
    var overdue: [TaskItem] { store.tasks.filter { $0.isOverdue && hit($0) } }
    var mineOpen: [TaskItem] { store.tasks.filter { !isAIWork($0) && !$0.isDone && hit($0) } }
    var aiOpen: [TaskItem] { store.tasks.filter { isAIWork($0) && !$0.isDone && hit($0) } }
    var doneToday: [TaskItem] { store.tasks.filter { $0.isDone && $0.doneDate == Store.today && hit($0) } }
    var doneEarlier: [TaskItem] { store.tasks.filter { $0.isDone && $0.doneDate != Store.today && hit($0) } }
    func who(_ t: TaskItem) -> String { t.doneBy.isEmpty || t.doneBy == "user" ? t.sourceBy : t.doneBy }

    func rowBox<V: View>(_ v: V) -> some View {
        v.listRowBackground(Color.clear).listRowSeparator(.hidden).listRowInsets(EdgeInsets(top: 4, leading: 18, bottom: 4, trailing: 18))
    }

    func row(_ t: TaskItem, needs: Bool = false) -> some View {
        LookRow(needs: needs,
                lead: {
                    Button { store.toggle(t) } label: { CheckCircle(on: t.isDone, working: !t.isDone && isAIWork(t)) }
                        .buttonStyle(.borderless)
                        .accessibilityLabel(t.isDone ? "Mark not done" : "Mark done")
                },
                title: t.title,
                sub: [t.area, t.isDone ? "" : (isAIWork(t) ? "AI work · Waiting" : ""), t.isDone && isAIWork(t) ? "AI work · Completed" : ""].filter { !$0.isEmpty }.joined(separator: " · "),
                trail: {
                    HStack(spacing: 6) {
                        if !who(t).isEmpty { AIFace(label: who(t), size: 34, state: needs ? .needs : .none) }
                        NavigationLink { TaskDetailView(taskId: t.id) } label: { Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundColor(.faint).frame(width: 28, height: 40) }
                            .accessibilityIdentifier("taskOpen-" + t.title)
                    }
                })
        .swipeActions { Button("Delete", role: .destructive) { store.deleteTask(t) } }
    }

    var summary: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) { Text("Open").font(.system(size: 12)).foregroundColor(.muted)
                Text("\(store.tasks.filter { !$0.isDone }.count)").font(.system(size: 30, weight: .bold)).foregroundColor(.loam) }.frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) { Text("Needs you").font(.system(size: 12)).foregroundColor(.muted)
                Text("\(store.needs.filter { $0.status == "open" }.count)").font(.system(size: 30, weight: .bold)).foregroundColor(.loam) }.frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) { Text("Done today").font(.system(size: 12)).foregroundColor(.muted)
                Text("\(store.tasks.filter { $0.isDone && $0.doneDate == Store.today }.count)").font(.system(size: 30, weight: .bold)).foregroundColor(Color(hex: 0x6E8A22)) }.frame(maxWidth: .infinity, alignment: .leading)
            PipArt(pose: .welcome, height: 58)
        }
        .padding(.horizontal, 16).padding(.vertical, 14).background(Color.cardTone).clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: Color.loam.opacity(0.07), radius: 12, y: 6)
    }

    func header(_ text: String, _ trailing: String = "") -> some View {
        rowBox(SectionLabel(text: text, trailing: trailing))
    }

    var body: some View {
        List {
            rowBox(Text("Made by your AIs from the talk").font(.system(size: 12.5)).foregroundColor(.muted))
            rowBox(summary)
            rowBox(PillTabs(items: ["All", "Needs you", "Mine", "AIs"], selection: $seg))
            if searching {
                rowBox(TextField("Search tasks", text: $query).textFieldStyle(.roundedBorder).accessibilityIdentifier("taskSearch"))
            }
            if !store.message.isEmpty {
                rowBox(Text(store.message).font(.footnote.weight(.medium)).foregroundColor(.red).accessibilityIdentifier("taskMessage"))
            }
            if store.kindnessOffer {
                rowBox(VStack(alignment: .leading, spacing: 8) {
                    Text("Nice work, that one is done.").font(.headline).foregroundColor(.loam)
                    Text("Kindness keeps NeedsMe free for the next person who needs a hand.")
                        .font(.subheadline).foregroundColor(.muted)
                    HStack {
                        NavigationLink { KindnessView() } label: {
                            Text("Join the AI kindness revolution").font(.subheadline.bold()).foregroundColor(.loam)
                        }.accessibilityIdentifier("kindnessMoment")
                        Spacer()
                        Button("Not now") { store.kindnessOffer = false }.font(.subheadline).foregroundColor(.muted)
                    }
                }
                .padding(16).background(LinearGradient(colors: [.sproutPale, .cardTone], startPoint: .leading, endPoint: .trailing))
                .clipShape(RoundedRectangle(cornerRadius: 20)))
            }
            if store.tasks.isEmpty && store.needs.isEmpty && store.message.isEmpty {
                rowBox(Text("No tasks yet. Tap + to add your first one.").foregroundColor(.muted))
            }
            if seg == 0 || seg == 1 {
                if !openNeeds.isEmpty || (seg == 0 && !overdue.isEmpty) {
                    header("Needs you (\(openNeeds.count + (seg == 0 ? overdue.count : 0)))", "rising to the top")
                    ForEach(openNeeds) { n in
                        rowBox(LookRow(needs: true, lead: { CheckCircle(on: false, working: true) }, title: n.text,
                                       sub: "\(n.ai) needs you",
                                       trail: { HStack(spacing: 8) { AIFace(label: n.ai, size: 34, state: .needs)
                                           Button("Done") { store.resolveNeed(n) }.font(.system(size: 12, weight: .bold)).padding(.horizontal, 10).padding(.vertical, 6)
                                               .background(Color.loam).foregroundColor(.bone).clipShape(Capsule()).buttonStyle(.borderless)
                                       } }))
                    }
                    if seg == 0 { ForEach(overdue) { t in rowBox(row(t, needs: true)) } }
                } else if seg == 1 {
                    rowBox(Text("Nothing needs you right now.").foregroundColor(.muted))
                }
            }
            if seg == 0 || seg == 2 {
                if !mineOpen.isEmpty { header("Your tasks (\(mineOpen.count))"); ForEach(mineOpen) { t in rowBox(row(t)) } }
            }
            if seg == 0 || seg == 3 {
                if !aiOpen.isEmpty { header("Your AIs are on it (\(aiOpen.count))"); ForEach(aiOpen) { t in rowBox(row(t)) } }
            }
            if seg != 1 {
                let d = doneToday.filter { seg == 0 || (seg == 2 ? !isAIWork($0) : isAIWork($0)) }
                let e = doneEarlier.filter { seg == 0 || (seg == 2 ? !isAIWork($0) : isAIWork($0)) }
                if !d.isEmpty { header("Done today (\(d.count))", "well done"); ForEach(d) { t in rowBox(row(t)) } }
                if !e.isEmpty { header("Earlier (\(e.count))"); ForEach(e) { t in rowBox(row(t)) } }
            }
            rowBox(Color.clear.frame(height: 24))
        }
        .listStyle(.plain).scrollContentBackground(.hidden).lookBg()
        .navigationTitle("Tasks")
        .toolbar { ToolbarItem(placement: .navigationBarTrailing) { SearchIconButton(on: $searching) } }
    }
}

/// Task detail (HTML section 9): the task's own records and nothing else. Fields with no
/// record behind them say so in plain words (section 19 honesty) — nothing is invented:
/// no priority and no outcome are recorded for any task in this app, so both say exactly that.
struct TaskDetailView: View {
    let taskId: String
    @EnvironmentObject var store: Store
    @Environment(\.palette) var p
    @Environment(\.dismiss) var dismiss
    @State private var newStep = ""

    var task: TaskItem? { store.tasks.first { $0.id == taskId } }
    var blockers: [TaskItem] { task.map { store.openDependencies($0) } ?? [] }
    var statusText: String {
        guard let t = task else { return "" }
        if t.isDone { return "Completed" }
        if let b = blockers.first { return "Blocked by " + b.title }
        return t.isOverdue ? "Waiting · overdue" : "Waiting"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let t = task {
                    Text(t.title).font(.title3.bold()).foregroundColor(p.ink)
                    fieldsCard(t)
                    checklistCard(t)
                    dependenciesCard(t)
                    timelineCard(t)
                    evidenceCard(t)
                    actionsCard(t)
                } else {
                    Text("This task is gone.").foregroundColor(p.soft)
                }
            }.padding()
        }
        .hidesTabBar().lookBg().navigationTitle("Task").navigationBarTitleDisplayMode(.inline)
    }

    func row2(_ k: String, _ v: String, id: String? = nil) -> some View {
        HStack(alignment: .top) {
            Text(k).foregroundColor(p.soft)
            Spacer()
            Text(v).bold().foregroundColor(p.ink).multilineTextAlignment(.trailing)
                .accessibilityIdentifier(id ?? "")
        }
    }

    func fieldsCard(_ t: TaskItem) -> some View {
        Card {
            Text("About this task").font(.headline).foregroundColor(p.ink)
            row2("Project", t.area.isEmpty ? "No project" : t.area)
            HStack(alignment: .top) {
                Text("Status").foregroundColor(p.soft)
                Spacer()
                Text(statusText).bold().foregroundColor(p.ink).accessibilityIdentifier("taskDetailStatus")
            }
            row2("Owner", t.sourceRoom.isEmpty ? "You" : "AI agent · filed by " + (t.sourceBy.isEmpty ? "an AI" : t.sourceBy))
            row2("Due", t.dueOn.isEmpty ? "No due date is set." : Store.niceDate(t.dueOn))
            Text("No priority is recorded for this task.").font(.subheadline).foregroundColor(p.soft)
            Text("No outcome is written for this task yet.").font(.subheadline).foregroundColor(p.soft)
        }
    }

    func checklistCard(_ t: TaskItem) -> some View {
        Card {
            Text("Checklist").font(.headline).foregroundColor(p.ink)
            if t.checklist.isEmpty {
                Text("No steps written for this task yet.").font(.subheadline).foregroundColor(p.soft)
            }
            ForEach(Array(t.checklist.enumerated()), id: \.offset) { pair in
                HStack(spacing: 10) {
                    Button {
                        var list = t.checklist
                        list[pair.offset].done.toggle()
                        store.saveChecklist(t, list)
                    } label: { SproutBox(on: pair.element.done, size: 24) }
                    .accessibilityLabel(pair.element.done ? "Mark step not done" : "Mark step done")
                    Text(pair.element.text).strikethrough(pair.element.done).foregroundColor(p.ink)
                    Spacer()
                    Button("Remove") {
                        var list = t.checklist
                        list.remove(at: pair.offset)
                        store.saveChecklist(t, list)
                    }.font(.subheadline).foregroundColor(p.soft)
                }
            }
            HStack(spacing: 8) {
                TextField("Add a step", text: $newStep).textFieldStyle(.roundedBorder).accessibilityIdentifier("checkNew")
                Button("Add") {
                    let s = newStep.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !s.isEmpty else { return }
                    store.saveChecklist(t, t.checklist + [CheckItem(text: s, done: false)])
                    newStep = ""
                }.buttonStyle(SoftButton()).accessibilityIdentifier("checkAdd")
                .disabled(newStep.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    func dependenciesCard(_ t: TaskItem) -> some View {
        Card {
            Text("Dependencies").font(.headline).foregroundColor(p.ink)
            Text("This task waits on these tasks finishing first.").font(.subheadline).foregroundColor(p.soft)
            if t.dependsOn.isEmpty {
                Text("No dependencies.").font(.subheadline).foregroundColor(p.ink)
            }
            ForEach(store.dependencyTasks(t)) { d in
                HStack(spacing: 10) {
                    Text(d.title).foregroundColor(p.ink)
                    Spacer()
                    Text(d.isDone ? "Done" : "Not done yet").font(.caption.bold()).foregroundColor(p.soft)
                    Button("Remove") { store.saveDependsOn(t, t.dependsOn.filter { $0 != d.id }) }
                        .font(.subheadline).foregroundColor(p.soft)
                }.accessibilityIdentifier("depRow-" + d.title)
            }
            let others = store.tasks.filter { $0.id != t.id && !t.dependsOn.contains($0.id) }
            if !others.isEmpty {
                Menu {
                    ForEach(others) { o in
                        Button(o.title) { store.saveDependsOn(t, t.dependsOn + [o.id]) }
                    }
                } label: {
                    Text("Add a dependency").font(.subheadline.bold()).foregroundColor(p.ink)
                        .padding(.horizontal, 12).padding(.vertical, 8).background(p.chip).clipShape(Capsule())
                }.accessibilityIdentifier("depAdd")
            }
        }
    }

    func timelineCard(_ t: TaskItem) -> some View {
        Card {
            Text("Session timeline").font(.headline).foregroundColor(p.ink)
            VStack(alignment: .leading, spacing: 6) {
                if let c = t.createdAt { Text("Filed " + Store.niceTime(c)).foregroundColor(p.ink) }
                if !t.sourceRoom.isEmpty {
                    Text("From the room \(t.sourceRoom) on \(Store.niceDate(t.sourceDate)), read by \(t.sourceBy)")
                        .foregroundColor(p.ink)
                }
                if t.isDone {
                    Text("Done" + (t.doneBy.isEmpty ? "" : " by \(t.doneBy == "user" ? "you" : t.doneBy)") + (t.doneDate.isEmpty ? "" : " on " + Store.niceDate(t.doneDate)))
                        .foregroundColor(p.ink)
                }
                Text("Current step: no live run is attached to this task.")
                    .font(.subheadline).foregroundColor(p.soft)
                Text("Last error: none is recorded for this task.")
                    .font(.subheadline).foregroundColor(p.soft)
            }
            .accessibilityElement(children: .contain).accessibilityIdentifier("taskTimeline")
        }
    }

    func evidenceCard(_ t: TaskItem) -> some View {
        Card {
            Text("Evidence").font(.headline).foregroundColor(p.ink)
            if t.stamp.isEmpty {
                Text("No room record stands behind this task. You filed it by hand.")
                    .font(.subheadline).foregroundColor(p.soft)
            } else {
                Text(t.stamp).font(.subheadline).foregroundColor(p.ink)
            }
            Text("No notes or files are linked to this task.").font(.subheadline).foregroundColor(p.soft)
        }
    }

    func actionsCard(_ t: TaskItem) -> some View {
        Card {
            Text("Actions").font(.headline).foregroundColor(p.ink)
            Button(t.isDone ? "Mark not done" : "Mark done") { store.toggle(t) }
                .buttonStyle(PrimaryButton()).accessibilityIdentifier("taskToggle")
            if store.kindnessOffer {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Nice work, that one is done.").font(.headline).foregroundColor(p.ink)
                    Text("Kindness keeps NeedsMe free for the next person who needs a hand.")
                        .font(.subheadline).foregroundColor(p.soft)
                    HStack {
                        NavigationLink { KindnessView() } label: {
                            Text("Join the AI kindness revolution").font(.subheadline.bold()).foregroundColor(p.ink)
                        }.accessibilityIdentifier("kindnessMoment")
                        Spacer()
                        Button("Not now") { store.kindnessOffer = false }.font(.subheadline).foregroundColor(p.soft)
                    }
                }
            }
            Button("Delete this task") { store.deleteTask(t); dismiss() }
                .buttonStyle(SoftButton()).accessibilityIdentifier("taskDelete")
        }
    }
}
