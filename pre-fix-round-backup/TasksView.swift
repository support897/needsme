import SwiftUI

struct TasksView: View {
    @EnvironmentObject var store: Store
    @Environment(\.palette) var p
    @State private var adding = false
    @State private var title = ""
    @State private var area = ""
    @State private var showKindness = false

    /// AI work carries a room stamp; everything else is hers (HTML section 9 owner types).
    func isAIWork(_ t: TaskItem) -> Bool { !t.sourceRoom.isEmpty }
    var mine: [TaskItem] { store.tasks.filter { !isAIWork($0) }.sorted { !$0.isDone && $1.isDone } }
    var aiWork: [TaskItem] { store.tasks.filter { isAIWork($0) }.sorted { !$0.isDone && $1.isDone } }

    func row(_ t: TaskItem) -> some View {
        HStack {
            Button {
                let wasDone = t.isDone
                store.toggle(t)
                if !wasDone { showKindness = true }
            } label: { SproutBox(on: t.isDone, size: 26) }
                .accessibilityLabel(t.isDone ? "Mark not done" : "Mark done")
            VStack(alignment: .leading) {
                Text(t.title).strikethrough(t.isDone).foregroundColor(p.ink)
                if !t.area.isEmpty { Text(t.area).font(.caption).foregroundColor(p.soft) }
                if !t.stamp.isEmpty { Text(t.stamp).font(.caption2).foregroundColor(p.soft) }
                if isAIWork(t) {
                    Text(t.isDone ? "AI work · Completed" : "AI work · Waiting").font(.caption2).foregroundColor(p.soft)
                }
            }
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
            if showKindness {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Nice work, that one is done.").font(.headline).foregroundColor(p.ink)
                    Text("Kindness keeps NeedsMe free for the next person who needs a hand.")
                        .font(.subheadline).foregroundColor(p.soft)
                    HStack {
                        NavigationLink { KindnessView() } label: {
                            Text("Join the AI kindness revolution").font(.subheadline.bold()).foregroundColor(p.ink)
                        }.accessibilityIdentifier("kindnessMoment")
                        Spacer()
                        Button("Not now") { showKindness = false }.font(.subheadline).foregroundColor(p.soft)
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
