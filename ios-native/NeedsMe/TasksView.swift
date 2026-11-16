import SwiftUI

struct TasksView: View {
    @EnvironmentObject var store: Store
    @Environment(\.palette) var p
    @State private var adding = false
    @State private var title = ""
    @State private var area = ""

    /// AI work carries a room stamp; everything else is hers (HTML section 9 owner types).
    func isAIWork(_ t: TaskItem) -> Bool { !t.sourceRoom.isEmpty }
    var mine: [TaskItem] { store.tasks.filter { !isAIWork($0) }.sorted { !$0.isDone && $1.isDone } }
    var aiWork: [TaskItem] { store.tasks.filter { isAIWork($0) }.sorted { !$0.isDone && $1.isDone } }

    func row(_ t: TaskItem) -> some View {
        HStack {
            Button {
                store.toggle(t)
            } label: { SproutBox(on: t.isDone, size: 26) }
                .buttonStyle(.borderless)
                .accessibilityLabel(t.isDone ? "Mark not done" : "Mark done")
            NavigationLink { TaskDetailView(taskId: t.id) } label: {
                VStack(alignment: .leading) {
                    Text(t.title).strikethrough(t.isDone).foregroundColor(p.ink)
                    if !t.area.isEmpty { Text(t.area).font(.caption).foregroundColor(p.soft) }
                    if !t.stamp.isEmpty { Text(t.stamp).font(.caption2).foregroundColor(p.soft) }
                    if isAIWork(t) {
                        Text(t.isDone ? "AI work · Completed" : "AI work · Waiting").font(.caption2).foregroundColor(p.soft)
                    }
                }
            }.buttonStyle(.plain).accessibilityIdentifier("taskOpen-" + t.title)
        }
        .listRowBackground(p.card)
        .swipeActions { Button("Delete", role: .destructive) { store.deleteTask(t) } }
    }

    var body: some View {
        List {
            if !store.message.isEmpty {
                Text(store.message).font(.footnote.weight(.medium)).foregroundColor(.red).accessibilityIdentifier("taskMessage")
                    .listRowBackground(p.card)
            }
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
                .listRowBackground(p.card)
            }
            if store.tasks.isEmpty && store.message.isEmpty {
                Text("No tasks yet. Tap + to add your first one.").foregroundColor(p.soft).listRowBackground(p.card)
            }
            if !mine.isEmpty {
                Section("Your tasks") { ForEach(mine) { t in row(t) } }
            }
            if !aiWork.isEmpty {
                Section("AI Work Queue") { ForEach(aiWork) { t in row(t) } }
            }
        }
            .scrollContentBackground(.hidden).background(p.bg)
            .navigationTitle("Tasks")
            .toolbar { Button { adding = true } label: { SproutPlus() }.accessibilityLabel("Add a task") }
            .sheet(isPresented: $adding) {
                NavigationStack {
                    Form {
                        TextField("What needs doing?", text: $title)
                        Picker("Project", selection: $area) { Text("None").tag(""); ForEach(store.projects, id: \.self) { Text($0).tag($0) } }
                        TextField("Or a new project name", text: $area)
                    }
                    .navigationTitle("New task")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { adding = false } }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Save") { store.addTask(title, area: area, due: ""); title = ""; area = ""; adding = false }.disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }
                }.presentationDetents([.medium])
            }
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
        .background(p.bg).navigationTitle("Task").navigationBarTitleDisplayMode(.inline)
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
