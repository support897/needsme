import SwiftUI

let aiNames = ["Claude", "ChatGPT", "Gemini", "Grok", "Perplexity", "Copilot"]

/// Three labelled places. They are never mixed in one list.
enum NotePlace: String, CaseIterable {
    case sent = "Prompts Sent", scheduled = "Prompts Scheduled", notes = "Notes"
    var id: String { switch self { case .sent: return "place-sent"; case .scheduled: return "place-scheduled"; case .notes: return "place-notes" } }
}

struct NotesView: View {
    @EnvironmentObject var store: Store
    @Environment(\.palette) var p
    @State private var place: NotePlace = .notes
    @State private var query = ""
    @State private var filter = ""
    @State private var showArchived = false
    @State private var openNote: NoteItem?
    @State private var newNote = false
    @State private var openPrompt: NoteItem?
    @State private var newPrompt = false
    @State private var toast = ""

    func matches(_ n: NoteItem) -> Bool {
        (filter.isEmpty || n.projects.contains(filter)) && (query.isEmpty || (n.title + n.body).localizedCaseInsensitiveContains(query))
    }
    var sentPrompts: [NoteItem] {
        store.notes.filter { $0.isPrompt && $0.state == "sent" && matches($0) }.sorted { ($0.sentAt ?? .distantPast) > ($1.sentAt ?? .distantPast) }
    }
    var waitingPrompts: [NoteItem] {
        store.notes.filter { $0.isPrompt && $0.state != "sent" && matches($0) }.sorted { ($0.scheduledFor ?? .distantFuture) < ($1.scheduledFor ?? .distantFuture) }
    }
    var noteList: [NoteItem] { store.notes.filter { !$0.isPrompt && $0.archived == showArchived && matches($0) } }
    var archivedCount: Int { store.notes.filter { !$0.isPrompt && $0.archived }.count }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        ForEach(NotePlace.allCases, id: \.self) { pl in
                            Button(pl.rawValue) { place = pl; showArchived = false }
                                .font(.subheadline.bold()).padding(.horizontal, 12).padding(.vertical, 8)
                                .background(place == pl ? p.ink : p.card).foregroundColor(place == pl ? p.bg : p.ink).clipShape(Capsule())
                                .accessibilityIdentifier(pl.id)
                        }
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            chip("All", filter.isEmpty) { filter = "" }
                            ForEach(store.projects, id: \.self) { n in chip(n, filter == n) { filter = n } }
                        }
                    }
                    switch place {
                    case .sent: sentList
                    case .scheduled: waitingList
                    case .notes: notesList
                    }
                }.padding()
            }
            .searchable(text: $query)
            .background(p.bg).navigationTitle(place.rawValue)
            .toolbar { Button { if place == .notes { newNote = true } else { newPrompt = true } } label: { SproutPlus() }.accessibilityLabel("New").accessibilityIdentifier("newItem") }
            .sheet(isPresented: $newNote) { NoteSheet(note: nil) }
            .sheet(item: $openNote) { n in NoteSheet(note: n) }
            .sheet(isPresented: $newPrompt) { PromptSheet(prompt: nil) { flash($0) } }
            .sheet(item: $openPrompt) { n in PromptSheet(prompt: n) { flash($0) } }
            .overlay(alignment: .bottom) {
                if !toast.isEmpty { Text(toast).padding(12).background(p.ink).foregroundColor(p.bg).clipShape(Capsule()).padding(.bottom, 12).transition(.opacity) }
            }
        }
    }

    @ViewBuilder var sentList: some View {
        if sentPrompts.isEmpty { Text("No prompts sent yet. Tap + to write one.").foregroundColor(p.soft) }
        ForEach(sentPrompts) { n in
            Card {
                Text(n.title).font(.headline).foregroundColor(p.ink)
                Text("Sent to \(n.roomTitle.isEmpty ? "a room" : n.roomTitle) at \(n.sentAt.map { Store.niceTime($0) } ?? "an unknown time")").font(.caption).foregroundColor(p.soft)
                Text(n.body).font(.subheadline).foregroundColor(p.soft)
                projectRow(n)
                Button("Copy to use") { UIPasteboard.general.string = n.body; flash("Copied.") }.buttonStyle(SoftButton())
            }
        }
    }

    @ViewBuilder var waitingList: some View {
        if waitingPrompts.isEmpty { Text("No prompts scheduled. Tap + to write one.").foregroundColor(p.soft) }
        ForEach(waitingPrompts) { n in
            Card {
                Text(n.title).font(.headline).foregroundColor(p.ink)
                if let at = n.scheduledFor {
                    Text("Goes to \(n.roomTitle.isEmpty ? "a room" : n.roomTitle) at \(Store.niceTime(at))").font(.caption).foregroundColor(p.soft)
                } else {
                    Text("Not scheduled yet. Edit it to pick a room and a time.").font(.caption).foregroundColor(p.soft)
                }
                Text(n.body).font(.subheadline).foregroundColor(p.soft)
                projectRow(n)
                HStack {
                    Button("Send now") { if n.room.isEmpty { openPrompt = n; flash("Pick a room first.") } else { store.sendPromptNow(n); flash("Sent.") } }
                        .buttonStyle(PrimaryButton()).accessibilityIdentifier("sendNow-" + n.id)
                    Button("Edit") { openPrompt = n }.buttonStyle(SoftButton())
                }
            }
        }
    }

    @ViewBuilder var notesList: some View {
        if showArchived {
            Button("Back to notes") { showArchived = false }.buttonStyle(SoftButton()).accessibilityIdentifier("backToNotes")
            Text("Archived notes").font(.headline).foregroundColor(p.ink)
        } else if archivedCount > 0 {
            Button("Archived (\(archivedCount))") { showArchived = true }.buttonStyle(SoftButton()).accessibilityIdentifier("showArchived")
        }
        if noteList.isEmpty { Text(showArchived ? "Nothing archived." : "No notes yet. Tap + to start one.").foregroundColor(p.soft) }
        ForEach(noteList) { n in
            Card {
                Button { openNote = n } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(n.title).font(.headline).foregroundColor(p.ink)
                        if !n.body.isEmpty { Text(NoteText.preview(n.body)).font(.subheadline).foregroundColor(p.soft).lineLimit(3) }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }.buttonStyle(.plain)
                projectRow(n)
                if showArchived {
                    Button("Restore") { store.setArchived(n, false); flash("Restored.") }.buttonStyle(PrimaryButton()).accessibilityIdentifier("restore-" + n.id)
                } else {
                    Button("Archive") { store.setArchived(n, true); flash("Archived.") }.buttonStyle(SoftButton()).accessibilityIdentifier("archive-" + n.id)
                }
            }
        }
    }

    /// One tap to fix a wrong guess: existing projects plus None. Her pick overrides the stamp.
    func projectRow(_ n: NoteItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Menu {
                Button("No project") { store.setProjects(n, []) }
                ForEach(store.projects, id: \.self) { name in
                    Button(n.projects.contains(name) ? "Take off \(name)" : "Put on \(name)") { store.toggleProject(n, name) }
                }
            } label: { tag(n.projects.isEmpty ? "No project" : n.projects.joined(separator: ", ")) }
                .accessibilityIdentifier("pick-" + n.id)
            if !n.stamp.isEmpty { Text(n.stamp).font(.caption2).foregroundColor(p.soft) }
        }
    }

    func flash(_ s: String) { toast = s; DispatchQueue.main.asyncAfter(deadline: .now() + 2) { toast = "" } }
    func chip(_ t: String, _ on: Bool, _ a: @escaping () -> Void) -> some View {
        Button(t, action: a).font(.subheadline.bold()).padding(.horizontal, 14).padding(.vertical, 8)
            .background(on ? p.ink : p.card).foregroundColor(on ? p.bg : p.ink).clipShape(Capsule())
    }
    func tag(_ t: String) -> some View {
        Text(t).font(.caption.bold()).padding(.horizontal, 10).padding(.vertical, 4).background(p.chip).foregroundColor(p.ink).clipShape(Capsule())
    }
}

/// Plain helpers for note text. A checklist line starts with "- [ ] " or "- [x] ".
enum NoteText {
    static let open = "- [ ] ", done = "- [x] "
    static func isCheck(_ line: String) -> Bool { line.hasPrefix(open) || line.hasPrefix(done) }
    static func clean(_ line: String) -> String { isCheck(line) ? String(line.dropFirst(open.count)) : line }
    static func preview(_ body: String) -> String { body.components(separatedBy: "\n").map { clean($0) }.joined(separator: "\n") }
    static func titleFrom(_ body: String) -> String {
        let first = body.components(separatedBy: "\n").map { clean($0).trimmingCharacters(in: .whitespaces) }.first { !$0.isEmpty } ?? "Untitled"
        return String(first.prefix(60))
    }
    /// Web addresses become links, so a tap opens them.
    static func linked(_ s: String) -> AttributedString {
        var a = AttributedString(s)
        guard let det = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return a }
        let len = (s as NSString).length
        for m in det.matches(in: s, range: NSRange(location: 0, length: len)) {
            guard let url = m.url, let r = Range(m.range, in: s),
                  let lo = AttributedString.Index(r.lowerBound, within: a),
                  let hi = AttributedString.Index(r.upperBound, within: a) else { continue }
            a[lo..<hi].link = url
        }
        return a
    }
    static func toggled(_ body: String, line index: Int) -> String {
        var lines = body.components(separatedBy: "\n")
        guard index < lines.count else { return body }
        if lines[index].hasPrefix(open) { lines[index] = done + String(lines[index].dropFirst(open.count)) }
        else if lines[index].hasPrefix(done) { lines[index] = open + String(lines[index].dropFirst(done.count)) }
        return lines.joined(separator: "\n")
    }
}

/// A note opens already typing. No title first. There is no delete here, only Archive.
struct NoteSheet: View {
    let note: NoteItem?
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) var dismiss
    @Environment(\.palette) var p
    @State private var id: String?
    @State private var text = ""
    @State private var editing = false
    @State private var lastSaved = ""
    @FocusState private var focus: Bool

    var current: NoteItem? { store.notes.first { $0.id == id } }

    var body: some View {
        NavigationStack {
            Group {
                if editing {
                    VStack(alignment: .leading, spacing: 8) {
                        TextEditor(text: $text).focused($focus).accessibilityIdentifier("noteBody")
                        HStack {
                            Button("Add a checklist line") {
                                if !text.isEmpty && !text.hasSuffix("\n") { text += "\n" }
                                text += NoteText.open
                            }.buttonStyle(SoftButton()).accessibilityIdentifier("addChecklist")
                        }
                        Text("Web addresses open when you tap them in the saved note.").font(.caption).foregroundColor(p.soft)
                    }.padding()
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            let lines = (current?.body ?? text).components(separatedBy: "\n")
                            ForEach(Array(lines.enumerated()), id: \.offset) { pair in
                                let line = pair.element
                                if NoteText.isCheck(line) {
                                    HStack(alignment: .top) {
                                        Button { tick(pair.offset) } label: {
                                            SproutBox(on: line.hasPrefix(NoteText.done), size: 24)
                                        }.accessibilityLabel(line.hasPrefix(NoteText.done) ? "Mark not done" : "Mark done")
                                        Text(NoteText.linked(NoteText.clean(line))).strikethrough(line.hasPrefix(NoteText.done)).foregroundColor(p.ink)
                                    }
                                } else {
                                    Text(NoteText.linked(line)).foregroundColor(p.ink)
                                }
                            }
                        }.frame(maxWidth: .infinity, alignment: .leading).padding()
                    }
                }
            }
            .background(p.bg)
            .navigationTitle(NoteText.titleFrom(text)).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { if editing { commit() }; dismiss() }.accessibilityIdentifier("noteClose")
                }
                ToolbarItemGroup(placement: .confirmationAction) {
                    if !editing, id != nil, let c = current {
                        Button("Archive") { store.setArchived(c, true); dismiss() }.accessibilityIdentifier("archiveNote")
                    }
                    if editing { Button("Done") { commit(); editing = false; focus = false; if id == nil { dismiss() } }.accessibilityIdentifier("noteDone") }
                    else { Button("Edit") { editing = true; focus = true }.accessibilityIdentifier("noteEdit") }
                }
            }
            .onAppear {
                if let n = note { id = n.id; text = n.body; lastSaved = n.body; editing = false }
                else { editing = true; DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { focus = true } }
            }
            .onDisappear { if editing { commit() } }
        }
    }

    func tick(_ index: Int) {
        guard let c = current else { return }
        let nb = NoteText.toggled(c.body, line: index)
        store.saveNote(id: c.id, title: c.title, body: nb, isPrompt: false)
        text = nb; lastSaved = nb
    }

    /// Saves the note. A blank new note is not saved. Never a delete.
    func commit() {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty && id == nil { return }
        if text == lastSaved { return }
        let title = NoteText.titleFrom(text)
        let saved = store.saveNote(id: id, title: title, body: text, isPrompt: false)
        if let saved {
            id = saved; lastSaved = text
            if !(current?.projectFixed ?? false) { store.autoMatch(id: saved, isPrompt: false, title: title, body: text) }
        }
    }
}

/// A prompt is a drafted message for a room. Send now, or schedule an exact time.
struct PromptSheet: View {
    let prompt: NoteItem?
    var onDone: (String) -> Void
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) var dismiss
    @State private var title = ""
    @State private var bodyText = ""
    @State private var roomId = ""
    @State private var when = Date().addingTimeInterval(3600)

    var room: RoomItem? { store.rooms.first { $0.id == roomId } }
    var ready: Bool { !bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && room != nil }
    var finalTitle: String { title.trimmingCharacters(in: .whitespaces).isEmpty ? NoteText.titleFrom(bodyText) : title }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $title)
                TextField("Prompt text", text: $bodyText, axis: .vertical).lineLimit(4...10).accessibilityIdentifier("promptText")
                Picker("Send to which room", selection: $roomId) {
                    Text("Choose a room").tag("")
                    ForEach(store.rooms) { Text($0.title).tag($0.id) }
                }.accessibilityIdentifier("promptRoom")
                DatePicker("Send at", selection: $when, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                Text("Sends at this time while NeedsMe is open. Closed app sending comes with the server wake.")
                    .font(.footnote).accessibilityIdentifier("scheduleNote")
                Button("Send now") {
                    store.savePrompt(id: prompt?.id, title: finalTitle, body: bodyText, room: room, sendNow: true, at: when)
                    onDone("Sent."); dismiss()
                }.disabled(!ready).accessibilityIdentifier("promptSendNow")
                Button("Schedule") {
                    store.savePrompt(id: prompt?.id, title: finalTitle, body: bodyText, room: room, sendNow: false, at: when)
                    onDone("Scheduled."); dismiss()
                }.disabled(!ready).accessibilityIdentifier("promptSchedule")
            }
            .navigationTitle(prompt == nil ? "New prompt" : "Edit prompt")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .onAppear {
                if prompt == nil, roomId.isEmpty { roomId = store.rooms.first?.id ?? "" }
                if let n = prompt {
                    title = n.title; bodyText = n.body; roomId = n.room
                    if let at = n.scheduledFor, at > Date() { when = at }
                }
            }
        }
    }
}
