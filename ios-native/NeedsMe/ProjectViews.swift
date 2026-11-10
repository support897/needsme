import SwiftUI

struct ProjectView: View {
    let name: String
    @EnvironmentObject var store: Store
    @Environment(\.palette) var p
    var body: some View {
        let pr = store.progress(name)
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Card {
                    Text("\(pr.done) of \(pr.total) tasks done").font(.headline).foregroundColor(p.ink)
                    ProgressView(value: Double(pr.done), total: Double(max(pr.total, 1))).tint(p.accent)
                }
                Text("Tasks").font(.title3.bold()).foregroundColor(p.ink)
                let ts = store.tasks.filter { $0.area == name }
                if ts.isEmpty { Text("No tasks in this project yet.").foregroundColor(p.soft) }
                ForEach(ts) { t in
                    Card {
                        HStack { SproutBox(on: t.isDone, size: 22)
                            Text(t.title).foregroundColor(p.ink).strikethrough(t.isDone) }
                        if !t.stamp.isEmpty { Text(t.stamp).font(.caption2).foregroundColor(p.soft) }
                    }
                }
                Text("Notes and prompts").font(.title3.bold()).foregroundColor(p.ink)
                let ns = store.notes.filter { $0.projects.contains(name) && !$0.archived }
                if ns.isEmpty { Text("No notes in this project yet.").foregroundColor(p.soft) }
                ForEach(ns) { n in
                    Card {
                        Text(n.title).font(.headline).foregroundColor(p.ink)
                        Text(n.isPrompt ? "Prompt for \(n.ai)" : "Note").font(.caption.bold()).foregroundColor(p.soft)
                    }
                }
            }.padding()
        }
        .background(p.bg)
        .navigationTitle(name).navigationBarTitleDisplayMode(.inline)
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
        .background(p.bg)
        .navigationTitle("Inbox").navigationBarTitleDisplayMode(.inline)
    }
}
