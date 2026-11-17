import SwiftUI

/// One change row, built only from stamps the records already carry (Changes spec, 12 Nov).
/// A missing who or when stays missing on the row. Nothing is guessed.
struct ChangeRow: Identifiable {
    let id: String
    let what: String
    let who: String
    let when: Date?
    let whenText: String
    let project: String   // "" means no project yet
}

@MainActor
enum Changes {
    static func dayText(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "d MMM"; return f.string(from: d)
    }
    static func dayTimeText(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "d MMM, HH:mm"; return f.string(from: d)
    }

    static func rows(_ store: Store) -> [ChangeRow] {
        var out: [ChangeRow] = []
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        for t in store.tasks {
            if !t.sourceRoom.isEmpty {
                let d = df.date(from: t.sourceDate)
                out.append(ChangeRow(id: "f-" + t.id, what: "To-do filed: \(t.title)",
                                     who: t.sourceBy.isEmpty ? "" : "from \(t.sourceBy)",
                                     when: d, whenText: t.sourceDate.isEmpty ? "" : Store.niceDate(t.sourceDate),
                                     project: t.area))
            } else {
                out.append(ChangeRow(id: "f-" + t.id, what: "To-do added: \(t.title)",
                                     who: "by you",
                                     when: t.createdAt, whenText: t.createdAt.map { dayText($0) } ?? "",
                                     project: t.area))
            }
            if t.isDone {
                let who = t.doneBy.isEmpty ? "" : (t.doneBy == "user" ? "by you" : "by \(t.doneBy)")
                let d = df.date(from: t.doneDate)
                out.append(ChangeRow(id: "d-" + t.id, what: "To-do done: \(t.title)",
                                     who: who,
                                     when: d, whenText: t.doneDate.isEmpty ? "" : Store.niceDate(t.doneDate),
                                     project: t.area))
            }
        }
        for n in store.notes where !n.archived {
            if n.isPrompt {
                // Only a prompt that has sent is a change made. A scheduled one is not.
                if n.state == "sent", let at = n.sentAt {
                    for proj in (n.projects.isEmpty ? [""] : n.projects) {
                        out.append(ChangeRow(id: "p-" + n.id + "|" + proj, what: "Prompt sent: \(n.title)",
                                             who: "", when: at, whenText: dayTimeText(at), project: proj))
                    }
                }
            } else {
                let who = n.projectFixed ? "set by you" : (!n.autoBy.isEmpty ? "matched by \(n.autoBy)" : "")
                for proj in (n.projects.isEmpty ? [""] : n.projects) {
                    out.append(ChangeRow(id: "n-" + n.id + "|" + proj, what: "Note added: \(n.title)",
                                         who: who, when: n.createdAt,
                                         whenText: n.createdAt.map { dayText($0) } ?? "", project: proj))
                }
            }
        }
        return out
    }

    /// Groups keyed by project name ("" = no project yet), projects in name order,
    /// the no-project group always last, rows newest first inside each group.
    static func groups(_ store: Store) -> [(project: String, rows: [ChangeRow])] {
        var byProject: [String: [ChangeRow]] = [:]
        for r in rows(store) { byProject[r.project, default: []].append(r) }
        let names = byProject.keys.filter { !$0.isEmpty }.sorted()
        var out: [(String, [ChangeRow])] = names.map { name in
            (name, byProject[name]!.sorted { ($0.when ?? .distantPast) > ($1.when ?? .distantPast) })
        }
        if let rest = byProject[""], !rest.isEmpty {
            out.append(("", rest.sorted { ($0.when ?? .distantPast) > ($1.when ?? .distantPast) }))
        }
        return out
    }
}

/// The Changes screen (build 341, item 1): every change, grouped by project, newest first.
/// Reads only. Needs-You items are not here by the spec: they live in Needs Me.
struct ChangesView: View {
    @EnvironmentObject var store: Store
    @Environment(\.palette) var p

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                let groups = Changes.groups(store)
                if groups.isEmpty {
                    Text("Nothing filed yet.").foregroundColor(p.soft).accessibilityIdentifier("changesEmpty")
                }
                ForEach(groups, id: \.project) { g in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            if !g.project.isEmpty {
                                Circle().fill(ProjectColor.color(g.project)).frame(width: 12, height: 12)
                            }
                            Text(g.project.isEmpty ? "No project yet" : g.project)
                                .font(.title3.bold()).foregroundColor(p.ink)
                            Spacer()
                            if !g.project.isEmpty {
                                if let pct = store.percentDone(g.project) {
                                    Text("\(pct)% done").font(.subheadline.bold()).foregroundColor(p.soft)
                                        .accessibilityIdentifier("changesPercent-" + g.project)
                                } else {
                                    Text("Progress not yet measurable").font(.caption).foregroundColor(p.soft)
                                }
                            }
                        }
                        ForEach(g.rows) { r in
                            Card {
                                Text(r.what).font(.headline).foregroundColor(p.ink)
                                let parts = [r.who, r.whenText].filter { !$0.isEmpty }
                                if !parts.isEmpty {
                                    Text(parts.joined(separator: " · ")).font(.caption).foregroundColor(p.soft)
                                }
                            }.accessibilityIdentifier("changeRow-" + r.id)
                        }
                    }
                }
            }.padding()
        }
        .hidesTabBar().lookBg().navigationTitle("Changes")
    }
}
