import SwiftUI

struct HomeView: View {
    @EnvironmentObject var store: Store
    @Environment(\.palette) var p
    var overdue: [TaskItem] { store.tasks.filter { $0.isOverdue } }
    var next: [TaskItem] { Array(store.tasks.filter { !$0.isDone }.prefix(3)) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Everything that needs you").foregroundColor(p.soft)
                    Card {
                        HStack(spacing: 12) {
                            PipImage(size: 48)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(overdue.isEmpty ? "All clear" : "\(overdue.count) overdue").font(.headline).foregroundColor(p.ink)
                                Text(overdue.isEmpty ? "Nothing needs you right now. Pip will tell you when something does." : overdue.map { $0.title }.prefix(2).joined(separator: ", "))
                                    .font(.subheadline).foregroundColor(p.soft)
                            }
                        }
                    }
                    Text("Start here").font(.title3.bold()).foregroundColor(p.ink)
                    if next.isEmpty { Text("No open tasks yet. Add one in Tasks.").foregroundColor(p.soft) }
                    ForEach(next) { t in
                        Card {
                            Text(t.title).font(.headline).foregroundColor(p.ink)
                            if !t.area.isEmpty { Text(t.area).font(.caption.bold()).padding(.horizontal, 10).padding(.vertical, 4).background(p.chip).clipShape(Capsule()).foregroundColor(p.ink) }
                            Button("Done") { store.toggle(t) }.buttonStyle(PrimaryButton()).frame(maxWidth: 140)
                        }
                    }
                    if !store.projects.isEmpty {
                        Text("Projects").font(.title3.bold()).foregroundColor(p.ink)
                        ForEach(store.projects, id: \.self) { name in
                            let pr = store.progress(name)
                            Card {
                                HStack { Text(name).font(.headline); Spacer(); Text("\(pr.done)/\(pr.total)").font(.subheadline).foregroundColor(p.soft) }.foregroundColor(p.ink)
                                ProgressView(value: Double(pr.done), total: Double(max(pr.total, 1))).tint(p.accent)
                                    .accessibilityLabel("\(name) progress")
                            }
                        }
                    }
                }.padding()
            }
            .background(p.bg)
            .navigationTitle("Hello, \(store.user?.displayName ?? "friend")")
        }
    }
}
