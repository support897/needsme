import SwiftUI

struct TasksView: View {
    @EnvironmentObject var store: Store
    @Environment(\.palette) var p
    @State private var adding = false
    @State private var title = ""
    @State private var area = ""

    var body: some View {
        NavigationStack {
            List {
                if !store.message.isEmpty {
                    Text(store.message).font(.footnote.weight(.medium)).foregroundColor(.red).accessibilityIdentifier("taskMessage")
                        .listRowBackground(p.card)
                }
                if store.tasks.isEmpty && store.message.isEmpty {
                    Text("No tasks yet. Tap + to add your first one.").foregroundColor(p.soft).listRowBackground(p.card)
                }
                ForEach(store.tasks.sorted { !$0.isDone && $1.isDone }) { t in
                    HStack {
                        Button { store.toggle(t) } label: { SproutBox(on: t.isDone, size: 26) }
                            .accessibilityLabel(t.isDone ? "Mark not done" : "Mark done")
                        VStack(alignment: .leading) {
                            Text(t.title).strikethrough(t.isDone).foregroundColor(p.ink)
                            if !t.area.isEmpty { Text(t.area).font(.caption).foregroundColor(p.soft) }
                            if !t.stamp.isEmpty { Text(t.stamp).font(.caption2).foregroundColor(p.soft) }
                        }
                    }
                    .listRowBackground(p.card)
                    .swipeActions { Button("Delete", role: .destructive) { store.deleteTask(t) } }
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
}
