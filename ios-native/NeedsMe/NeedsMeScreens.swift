import SwiftUI

/// The Needs Me screen (HTML section 6): the human attention inbox as its own destination.
/// Items are grouped by project and every item deep links to the exact room it came from.
struct NeedsMeView: View {
    @EnvironmentObject var store: Store
    @Environment(\.palette) var p

    var openNeeds: [NeedItem] { store.needs.filter { $0.status == "open" } }
    var overdue: [TaskItem] { store.tasks.filter { $0.isOverdue } }
    var unsorted: [NoteItem] { store.notes.filter { $0.projects.isEmpty && !$0.archived } }
    var allClear: Bool { openNeeds.isEmpty && overdue.isEmpty && unsorted.isEmpty }

    /// Open needs grouped by the project of the room they came from. No project goes last.
    var groups: [(project: String, items: [NeedItem])] {
        var byProject: [String: [NeedItem]] = [:]
        for n in openNeeds {
            let proj = store.rooms.first { $0.id == n.roomId }?.project ?? ""
            byProject[proj, default: []].append(n)
        }
        var out = byProject.keys.filter { !$0.isEmpty }.sorted().map { (project: $0, items: byProject[$0]!) }
        if let rest = byProject[""], !rest.isEmpty { out.append((project: "", items: rest)) }
        return out
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if allClear {
                        Card {
                            HStack(spacing: 12) {
                                PipImage(size: 48)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Nothing needs you right now").font(.headline).foregroundColor(p.ink)
                                    Text("When an AI needs a decision, an answer or a login, it waits here for you.")
                                        .font(.subheadline).foregroundColor(p.soft)
                                }
                            }
                        }.accessibilityIdentifier("needsAllClear")
                    }
                    ForEach(groups, id: \.project) { g in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 8) {
                                if !g.project.isEmpty { Circle().fill(ProjectColor.color(g.project)).frame(width: 12, height: 12) }
                                Text(g.project.isEmpty ? "No project yet" : g.project).font(.title3.bold()).foregroundColor(p.ink)
                                Spacer()
                                Text(g.items.count == 1 ? "1 needs you" : "\(g.items.count) need you")
                                    .font(.subheadline.bold()).foregroundColor(p.soft)
                            }
                            ForEach(g.items) { n in needCard(n) }
                        }
                    }
                    if !overdue.isEmpty {
                        Text("Overdue").font(.title3.bold()).foregroundColor(p.ink)
                        ForEach(overdue) { t in
                            Card {
                                Text("Overdue: \(t.title)").font(.headline).foregroundColor(p.ink)
                                Text("Due \(t.dueOn)").font(.caption).foregroundColor(p.soft)
                            }
                        }
                    }
                    if !unsorted.isEmpty {
                        Text("Needs a project").font(.title3.bold()).foregroundColor(p.ink)
                        ForEach(unsorted) { n in
                            Card {
                                Text("Needs a project: \(n.title)").font(.headline).foregroundColor(p.ink)
                                Text("Open Notes and pick a project for it.").font(.caption).foregroundColor(p.soft)
                            }
                        }
                    }
                }.padding()
            }
            .background(p.bg).navigationTitle("Needs Me")
        }
    }

    func needCard(_ n: NeedItem) -> some View {
        Card {
            Text("\(n.ai) needs you").font(.headline).foregroundColor(p.ink)
            Text(n.text).font(.subheadline).foregroundColor(p.ink)
            HStack(spacing: 8) {
                if let room = store.rooms.first(where: { $0.id == n.roomId }) {
                    NavigationLink { RoomView(room: room, store: store) } label: {
                        Text("Open the room").font(.system(.body, design: .rounded).weight(.semibold))
                            .padding(.vertical, 10).padding(.horizontal, 14)
                            .background(p.chip).foregroundColor(p.ink).clipShape(Capsule())
                    }.accessibilityIdentifier("needOpen-" + n.id)
                }
                Button("Done") { store.resolveNeed(n) }.buttonStyle(SoftButton()).frame(maxWidth: 120)
                    .accessibilityIdentifier("needDone-" + n.id)
            }
        }.accessibilityIdentifier("need-" + n.id)
    }
}

/// The Projects tab (HTML section 7): every project with its own colour, its progress and
/// how that progress was counted. A project with no tasks yet says so instead of inventing a number.
struct ProjectsView: View {
    @EnvironmentObject var store: Store
    @Environment(\.palette) var p

    func needsCount(_ name: String) -> Int {
        let roomIds = Set(store.rooms.filter { $0.project == name }.map { $0.id })
        return store.needs.filter { $0.status == "open" && roomIds.contains($0.roomId) }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    NavigationLink { YourProgressView() } label: {
                        Card {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Your Progress").font(.headline).foregroundColor(p.ink)
                                    Text("Look what moved forward").font(.subheadline).foregroundColor(p.soft)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").foregroundColor(p.soft)
                            }
                        }
                    }.buttonStyle(.plain).accessibilityIdentifier("yourProgress")
                    if store.projects.isEmpty {
                        Text("No projects yet. A project appears when a task or a note names one.")
                            .foregroundColor(p.soft).accessibilityIdentifier("noProjects")
                    }
                    ForEach(store.projects, id: \.self) { name in
                        let pr = store.progress(name)
                        NavigationLink { ProjectView(name: name) } label: {
                            Card {
                                HStack(spacing: 8) {
                                    Circle().fill(ProjectColor.color(name)).frame(width: 12, height: 12)
                                    Text(name).font(.headline).foregroundColor(p.ink)
                                    Spacer()
                                    if let pct = store.percentDone(name) {
                                        Text("\(pct)% done").font(.subheadline.bold()).foregroundColor(p.soft)
                                    }
                                }
                                if pr.total > 0 {
                                    Text("\(pr.done) of \(pr.total) tasks done").font(.subheadline).foregroundColor(p.soft)
                                    ProgressView(value: Double(pr.done), total: Double(pr.total)).tint(ProjectColor.color(name))
                                        .accessibilityLabel("\(name) progress")
                                } else {
                                    Text("Progress not yet measurable. This project has notes, but no tasks yet.")
                                        .font(.subheadline).foregroundColor(p.soft)
                                }
                                let k = needsCount(name)
                                if k > 0 { Text(k == 1 ? "1 needs you" : "\(k) need you").font(.caption.bold()).foregroundColor(p.ink) }
                            }
                        }.buttonStyle(.plain).accessibilityIdentifier("project-" + name)
                    }
                }.padding()
            }
            .background(p.bg).navigationTitle("Projects")
        }
    }
}

/// Your Progress (HTML section 8): what moved forward, counted only from finished tasks and
/// their own date stamps. Gentle words, no scores, no streaks.
struct YourProgressView: View {
    @EnvironmentObject var store: Store
    @Environment(\.palette) var p

    var doneThisWeek: [TaskItem] {
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return store.tasks.filter { t in
            guard t.isDone, let d = df.date(from: t.doneDate) else { return false }
            return d >= Calendar.current.startOfDay(for: weekAgo)
        }
    }
    var movingProjects: [String] { Array(Set(doneThisWeek.map { $0.area }.filter { !$0.isEmpty })).sorted() }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Look what moved forward").font(.title3.bold()).foregroundColor(p.ink)
                Card {
                    Text(doneThisWeek.isEmpty ? "Nothing finished this week yet." : "\(doneThisWeek.count) finished this week")
                        .font(.headline).foregroundColor(p.ink)
                    ForEach(doneThisWeek) { t in
                        HStack(spacing: 8) {
                            SproutBox(on: true, size: 20)
                            Text(t.title).foregroundColor(p.ink)
                            if !t.doneBy.isEmpty, t.doneBy != "user" {
                                Text("by \(t.doneBy)").font(.caption).foregroundColor(p.soft)
                            }
                        }
                    }
                }
                Card {
                    Text("Projects moving forward").font(.headline).foregroundColor(p.ink)
                    if movingProjects.isEmpty {
                        Text("No project moved this week yet.").font(.subheadline).foregroundColor(p.soft)
                    }
                    ForEach(movingProjects, id: \.self) { name in
                        HStack(spacing: 8) {
                            Circle().fill(ProjectColor.color(name)).frame(width: 10, height: 10)
                            Text(name).foregroundColor(p.ink)
                        }
                    }
                }
                Card {
                    Text("Finished in total").font(.headline).foregroundColor(p.ink)
                    Text("\(store.tasks.filter { $0.isDone }.count) to-dos finished, counted from your own task list.")
                        .font(.subheadline).foregroundColor(p.soft)
                }
                Text("That's enough for today.").font(.subheadline).foregroundColor(p.soft)
            }.padding()
        }
        .background(p.bg).navigationTitle("Your Progress").navigationBarTitleDisplayMode(.inline)
    }
}
