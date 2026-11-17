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
                VStack(alignment: .leading, spacing: 14) {
                    if allClear {
                        HStack(spacing: 12) {
                            PipArt(pose: .welcome, height: 70)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Nothing needs you right now").font(.headline).foregroundColor(.loam)
                                Text("When an AI needs a decision, an answer or a login, it waits here for you.")
                                    .font(.subheadline).foregroundColor(.muted)
                            }
                        }
                        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                        .background(LinearGradient(colors: [.sproutPale, .cardTone], startPoint: .leading, endPoint: .trailing))
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .accessibilityElement(children: .contain).accessibilityIdentifier("needsAllClear")
                    }
                    ForEach(groups, id: \.project) { g in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 8) {
                                if !g.project.isEmpty { Circle().fill(ProjectColor.color(g.project)).frame(width: 12, height: 12) }
                                Text(g.project.isEmpty ? "No project yet" : g.project).font(.title3.bold()).foregroundColor(.loam)
                                Spacer()
                                CountPill(text: g.items.count == 1 ? "1 needs you" : "\(g.items.count) need you")
                            }
                            ForEach(g.items) { n in needCard(n) }
                        }
                    }
                    if !overdue.isEmpty {
                        SectionLabel(text: "Overdue")
                        ForEach(overdue) { t in
                            LookRow(needs: true, lead: { CheckCircle(on: false, working: true) }, title: "Overdue: \(t.title)", sub: "Due \(t.dueOn)", trail: { EmptyView() })
                        }
                    }
                    if !unsorted.isEmpty {
                        SectionLabel(text: "Needs a project")
                        ForEach(unsorted) { n in
                            LookRow(lead: { Image(systemName: "doc.text").foregroundColor(.loam).frame(width: 26) }, title: "Needs a project: \(n.title)", sub: "Open Notes and pick a project for it.", trail: { EmptyView() })
                        }
                    }
                }.padding(.horizontal, 18).padding(.bottom, 12)
            }
            .background(Color.clear).navigationTitle("Needs Me")
        }
    }

    func needCard(_ n: NeedItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                AIFace(label: n.ai, size: 34, state: .needs)
                Text("\(n.ai) needs you").font(.system(size: 16, weight: .bold)).foregroundColor(.loam)
            }
            Text(n.text).font(.system(size: 14.5)).foregroundColor(.loam)
            HStack(spacing: 8) {
                if let room = store.rooms.first(where: { $0.id == n.roomId }) {
                    NavigationLink { RoomView(room: room, store: store) } label: {
                        Text("Open the room").font(.system(size: 14, weight: .semibold))
                            .padding(.vertical, 10).padding(.horizontal, 14)
                            .background(Color.cardTone.opacity(0.9)).foregroundColor(.loam).clipShape(Capsule())
                    }.accessibilityIdentifier("needOpen-" + n.id)
                }
                Button("Done") { store.resolveNeed(n) }.buttonStyle(SoftButton()).frame(maxWidth: 120)
                    .accessibilityIdentifier("needDone-" + n.id)
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(LinearGradient(colors: [.sproutMid, Color(hex: 0xE8EDCB), Color(hex: 0xF4F0E4)], startPoint: .topLeading, endPoint: .bottomTrailing))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: Color.loam.opacity(0.07), radius: 10, y: 5)
        .accessibilityElement(children: .contain).accessibilityIdentifier("need-" + n.id)
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
                VStack(alignment: .leading, spacing: 12) {
                    NavigationLink { YourProgressView() } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Your Progress").font(.headline).foregroundColor(.loam)
                                Text("Look what moved forward").font(.subheadline).foregroundColor(.muted)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundColor(.muted)
                        }
                        .padding(16).background(LinearGradient(colors: [.sproutPale, .cardTone], startPoint: .leading, endPoint: .trailing))
                        .clipShape(RoundedRectangle(cornerRadius: 24)).shadow(color: Color.loam.opacity(0.06), radius: 10, y: 5)
                    }.buttonStyle(.plain).accessibilityIdentifier("yourProgress")
                    if store.projects.isEmpty {
                        Text("No projects yet. A project appears when a task or a note names one.")
                            .foregroundColor(.muted).accessibilityIdentifier("noProjects")
                    }
                    ForEach(store.projects, id: \.self) { name in
                        let pr = store.progress(name)
                        let k = needsCount(name)
                        NavigationLink { ProjectView(name: name) } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                ProjectCardLook(name: name, done: pr.done, total: pr.total)
                                if pr.total == 0 {
                                    Text("This project has notes, but no tasks yet.").font(.system(size: 12)).foregroundColor(.muted).padding(.horizontal, 6)
                                }
                                if k > 0 { Text(k == 1 ? "1 needs you" : "\(k) need you").font(.system(size: 12, weight: .bold)).foregroundColor(.loam).padding(.horizontal, 6) }
                            }
                        }.buttonStyle(.plain).accessibilityIdentifier("project-" + name)
                    }
                }.padding(.horizontal, 18).padding(.bottom, 12)
            }
            .background(Color.clear).navigationTitle("Projects")
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
