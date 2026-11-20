import SwiftUI
import PhotosUI
import PencilKit

let aiNames = ["Claude", "ChatGPT", "Gemini", "Grok", "Perplexity", "Copilot"]

/// Three labelled places. They are never mixed in one list.
enum NotePlace: String, CaseIterable {
    case sent = "Prompts Sent", scheduled = "Prompts Scheduled", notes = "Notes"
    var id: String { switch self { case .sent: return "place-sent"; case .scheduled: return "place-scheduled"; case .notes: return "place-notes" } }
}

struct NotesView: View {
    @EnvironmentObject var store: Store
    @Environment(\.palette) var p
    @EnvironmentObject var router: TabRouter
    @State private var place: NotePlace = .notes
    @State private var query = ""
    @State private var filter = ""
    @State private var showArchived = false
    @State private var toDelete: NoteItem? = nil
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
        store.notes.filter { $0.isPrompt && $0.state != "sent" && $0.state != "cancelled" && matches($0) }.sorted { ($0.scheduledFor ?? .distantFuture) < ($1.scheduledFor ?? .distantFuture) }
    }
    var noteList: [NoteItem] { store.notes.filter { !$0.isPrompt && $0.archived == showArchived && matches($0) } }
    var archivedCount: Int { store.notes.filter { !$0.isPrompt && $0.archived }.count }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(place == .notes ? "Written by your AIs, kept for you" : "Your prompts, kept for you")
                        .font(.system(size: 12.5)).foregroundColor(.muted)
                    HStack(spacing: 6) {
                        ForEach(NotePlace.allCases, id: \.self) { pl in
                            Button { place = pl; showArchived = false } label: {
                                Text(pl.rawValue).font(.system(size: 13, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.75)
                                    .frame(maxWidth: .infinity).padding(.vertical, 9)
                                    .background(place == pl ? Color.loam : Color.clear)
                                    .foregroundColor(place == pl ? Color.bone : Color.muted)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                            }.buttonStyle(.plain).accessibilityIdentifier(pl.id)
                        }
                    }
                    .padding(5).background(Color.loam.opacity(0.06)).clipShape(RoundedRectangle(cornerRadius: 18))
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
                }.padding(.horizontal, 18).padding(.bottom, 12)
            }
            .searchable(text: $query)
            .lookBg().navigationTitle(place == .notes ? "Notes" : place.rawValue)
            .onChange(of: router.noteTick) { _ in if place == .notes { newNote = true } else { newPrompt = true } }
            .fullScreenCover(isPresented: $newNote) { NoteSheet(note: nil) }
            .fullScreenCover(item: $openNote) { n in NoteSheet(note: n) }
            .fullScreenCover(isPresented: $newPrompt) { PromptSheet(prompt: nil) { flash($0) } }
            .alert("Delete this note?", isPresented: Binding(get: { toDelete != nil }, set: { if !$0 { toDelete = nil } })) {
                Button("Delete", role: .destructive) { if let n = toDelete { store.deleteNote(n); flash("Deleted.") }; toDelete = nil }
                Button("Cancel", role: .cancel) { toDelete = nil }
            } message: { Text("This cannot be undone.") }
            .fullScreenCover(item: $openPrompt) { n in PromptSheet(prompt: n) { flash($0) } }
            .overlay(alignment: .bottom) {
                if !toast.isEmpty { Text(toast).padding(12).background(Color.loam).foregroundColor(Color.bone).clipShape(Capsule()).padding(.bottom, 96).transition(.opacity) }
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
                if n.state == "scheduled" {
                    Button("Cancel this prompt") { store.cancelScheduledPrompt(n); flash("Cancelled. It will not send.") }
                        .buttonStyle(SoftButton()).accessibilityIdentifier("cancelPrompt-" + n.id)
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
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            ForEach(noteList) { n in noteCard(n) }
        }
    }

    static func niceDate(_ d: Date?) -> String {
        guard let d else { return "" }
        let f = DateFormatter()
        if Calendar.current.isDateInToday(d) { f.timeStyle = .short; f.dateStyle = .none }
        else { f.dateStyle = .short; f.timeStyle = .none }
        return f.string(from: d)
    }

    /// A note as a small square, like the Apple Notes gallery: bold title, a few lines, the date.
    func noteCard(_ n: NoteItem) -> some View {
        let fromAI = !n.ai.isEmpty
        let lines = NoteText.preview(n.body).components(separatedBy: "\n").dropFirst().joined(separator: " ")
        return Button { openNote = n } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(n.title).font(.system(size: 15, weight: .bold)).foregroundColor(p.ink).lineLimit(2).multilineTextAlignment(.leading)
                Text(lines).font(.system(size: 12.5)).foregroundColor(p.soft).lineLimit(4).multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                HStack(spacing: 6) {
                    Text(NotesView.niceDate(n.updatedAt ?? n.createdAt)).font(.system(size: 11)).foregroundColor(p.soft)
                    Spacer()
                    if fromAI { AIFace(label: n.ai, size: 22) }
                    if let first = n.projects.first { Text(first).font(.system(size: 10, weight: .bold)).lineLimit(1).padding(.horizontal, 7).padding(.vertical, 3).background(p.chip).clipShape(Capsule()) }
                }
            }
            .padding(14).frame(maxWidth: .infinity, minHeight: 156, maxHeight: 156, alignment: .topLeading)
            .background(Group { if fromAI { LinearGradient(colors: [.sproutPale, .cardTone], startPoint: .topLeading, endPoint: .bottomTrailing) } else { Color.cardTone } })
            .clipShape(RoundedRectangle(cornerRadius: 20)).shadow(color: Color.loam.opacity(0.07), radius: 8, y: 4)
        }
        .buttonStyle(.plain).accessibilityIdentifier("note-" + n.id)
        .contextMenu {
            if showArchived { Button { store.setArchived(n, false); flash("Restored.") } label: { Label("Restore", systemImage: "arrow.uturn.backward") } }
            else { Button { store.setArchived(n, true); flash("Archived.") } label: { Label("Archive", systemImage: "archivebox") } }
            Menu("Project") {
                Button("No project") { store.setProjects(n, []) }
                ForEach(store.projects, id: \.self) { name in
                    Button(n.projects.contains(name) ? "Take off \(name)" : "Put on \(name)") { store.toggleProject(n, name) }
                }
            }
            Button(role: .destructive) { toDelete = n } label: { Label("Delete", systemImage: "trash") }
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
            .background(on ? Color.loam : Color.cardTone).foregroundColor(on ? Color.bone : Color.loam).clipShape(Capsule())
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


private let notesYellow = Color(hex: 0xE0A800)

/// A note is the whole screen and you are already typing, like Apple Notes. No modes.
/// Bottom bar: checklist, picture, drawing. Pictures and drawings sit under the text.
struct NoteSheet: View {
    let note: NoteItem?
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) var dismiss
    @Environment(\.palette) var p
    @State private var id: String?
    @State private var text = ""
    @State private var lastSaved = ""
    @State private var pickerItem: PhotosPickerItem?
    @State private var attachNote = ""
    @State private var drawing = false
    @State private var askDelete = false
    @FocusState private var focus: Bool

    var current: NoteItem? { store.notes.first { $0.id == id } }
    var checkLines: [(Int, String)] {
        text.components(separatedBy: "\n").enumerated().filter { NoteText.isCheck($0.element) }.map { ($0.offset, $0.element) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        TextEditor(text: $text).focused($focus).scrollContentBackground(.hidden)
                            .frame(minHeight: 280).accessibilityIdentifier("noteBody")
                        if !checkLines.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(checkLines, id: \.0) { pair in
                                    HStack(alignment: .top) {
                                        Button { tick(pair.0) } label: { SproutBox(on: pair.1.hasPrefix(NoteText.done), size: 24) }
                                            .accessibilityLabel(pair.1.hasPrefix(NoteText.done) ? "Mark not done" : "Mark done")
                                        Text(NoteText.clean(pair.1)).strikethrough(pair.1.hasPrefix(NoteText.done)).foregroundColor(p.ink)
                                    }
                                }
                            }.padding(12).background(p.chip.opacity(0.5)).clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        attachmentsSection
                        if !attachNote.isEmpty { Text(attachNote).font(.subheadline).foregroundColor(p.soft) }
                    }.padding(.horizontal, 16).padding(.top, 4)
                }
                bottomBar
            }
            .background(Color(.systemBackground).ignoresSafeArea())
            .navigationTitle("").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { commit(); dismiss() } label: { HStack(spacing: 2) { Image(systemName: "chevron.left"); Text("Notes") } }
                        .tint(notesYellow).accessibilityIdentifier("noteClose")
                }
                ToolbarItemGroup(placement: .confirmationAction) {
                    if id != nil, let c = current {
                        Menu {
                            Button { store.setArchived(c, true); dismiss() } label: { Label("Archive", systemImage: "archivebox") }.accessibilityIdentifier("archiveNote")
                            Button(role: .destructive) { askDelete = true } label: { Label("Delete", systemImage: "trash") }
                            ShareLink(item: text) { Label("Share", systemImage: "square.and.arrow.up") }
                        } label: { Image(systemName: "ellipsis.circle") }.tint(notesYellow).accessibilityLabel("More")
                    }
                    Button("Done") { commit(); focus = false }.tint(notesYellow).bold().accessibilityIdentifier("noteDone")
                }
            }
            .alert("Delete this note?", isPresented: $askDelete) {
                Button("Delete", role: .destructive) { if let c = current { store.deleteNote(c) }; dismiss() }
                Button("Cancel", role: .cancel) {}
            } message: { Text("This cannot be undone.") }
            .sheet(isPresented: $drawing) { DrawSheet { img in addImage(img.pngData() ?? Data()) } }
            .onAppear {
                if let n = note { id = n.id; text = n.body; lastSaved = n.body; store.listenAttachments(n.id) }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { focus = (note == nil) }
            }
            .onChange(of: id) { newId in if let newId { store.listenAttachments(newId) } }
            .onChange(of: pickerItem) { item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self) { addImage(data) }
                    pickerItem = nil
                }
            }
            .onDisappear { commit() }
        }
    }

    var bottomBar: some View {
        HStack(spacing: 30) {
            Button { if !text.isEmpty && !text.hasSuffix("\n") { text += "\n" }; text += NoteText.open; focus = true } label: {
                Image(systemName: "checklist").font(.system(size: 21))
            }.accessibilityLabel("Add a checklist line").accessibilityIdentifier("addChecklist")
            PhotosPicker(selection: $pickerItem, matching: .images) { Image(systemName: "photo.on.rectangle").font(.system(size: 21)) }
                .accessibilityLabel("Add a picture").accessibilityIdentifier("attachPhoto")
            Button { commit(forceSave: true); drawing = true } label: { Image(systemName: "pencil.tip.crop.circle").font(.system(size: 22)) }
                .accessibilityLabel("Draw").accessibilityIdentifier("drawButton")
            Spacer()
            Button { focus.toggle() } label: {
                Image(systemName: focus ? "keyboard.chevron.compact.down" : "square.and.pencil").font(.system(size: 21))
            }.accessibilityLabel("Keyboard")
        }
        .tint(notesYellow).foregroundColor(notesYellow)
        .padding(.horizontal, 22).padding(.vertical, 12).background(.bar)
    }

    @ViewBuilder var attachmentsSection: some View {
        if let nid = id, current != nil {
            let atts = store.noteImages[nid] ?? []
            ForEach(atts) { a in
                if let ui = UIImage(data: a.data) {
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: ui).resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 12))
                            .accessibilityIdentifier("noteAttachmentImage")
                        Button { store.removeAttachment(noteId: nid, a) } label: {
                            Image(systemName: "xmark.circle.fill").font(.system(size: 26)).foregroundColor(.white).shadow(radius: 3)
                        }.padding(8).accessibilityLabel("Remove picture").accessibilityIdentifier("attachRemove")
                    }
                }
            }
        }
    }

    func addImage(_ data: Data) {
        if id == nil { commit(forceSave: true) }
        guard let nid = id, !data.isEmpty else { attachNote = "Could not keep that picture."; return }
        attachNote = store.addAttachment(noteId: nid, raw: data) ? "" : "That picture is too large to keep with the note."
    }

    func tick(_ index: Int) {
        let nb = NoteText.toggled(text, line: index)
        text = nb; commit()
    }

    /// Saves the note. A blank new note is not saved unless a picture needs a home. Never a delete.
    func commit(forceSave: Bool = false) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty && id == nil && !forceSave { return }
        if text == lastSaved && id != nil { return }
        let title = t.isEmpty ? "Untitled" : NoteText.titleFrom(text)
        let saved = store.saveNote(id: id, title: title, body: text, isPrompt: false)
        if let saved {
            id = saved; lastSaved = text
            if !(current?.projectFixed ?? false) { store.autoMatch(id: saved, isPrompt: false, title: title, body: text) }
        }
    }
}

/// Draw with a finger or Apple Pencil. Done keeps it in the note as a picture.
struct DrawSheet: View {
    var onDone: (UIImage) -> Void
    @Environment(\.dismiss) var dismiss
    @State private var canvas = PKCanvasView()
    var body: some View {
        NavigationStack {
            DrawCanvas(canvas: $canvas).ignoresSafeArea(.container, edges: .bottom)
                .navigationTitle("Draw").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.tint(notesYellow) }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            let b = canvas.bounds.isEmpty ? CGRect(x: 0, y: 0, width: 600, height: 800) : canvas.bounds
                            let ink = canvas.drawing.image(from: b, scale: 2)
                            let out = UIGraphicsImageRenderer(size: b.size).image { ctx in
                                UIColor.white.setFill(); ctx.fill(b); ink.draw(in: b)
                            }
                            if !canvas.drawing.bounds.isEmpty { onDone(out) }
                            dismiss()
                        }.bold().tint(notesYellow).accessibilityIdentifier("drawDone")
                    }
                }
        }
    }
}

struct DrawCanvas: UIViewRepresentable {
    @Binding var canvas: PKCanvasView
    func makeUIView(context: Context) -> PKCanvasView {
        canvas.drawingPolicy = .anyInput
        canvas.backgroundColor = .white
        canvas.overrideUserInterfaceStyle = .light
        canvas.tool = PKInkingTool(.pen, color: .black, width: 4)
        let picker = PKToolPicker()
        picker.setVisible(true, forFirstResponder: canvas)
        picker.addObserver(canvas)
        context.coordinator.picker = picker
        DispatchQueue.main.async { canvas.becomeFirstResponder() }
        return canvas
    }
    func updateUIView(_ ui: PKCanvasView, context: Context) {}
    func makeCoordinator() -> Coord { Coord() }
    final class Coord { var picker: PKToolPicker? }
}

/// A prompt is a drafted message for a room. Same full screen page as a note. The bottom bar
/// picks the room and the time, and sends now or schedules.
struct PromptSheet: View {
    let prompt: NoteItem?
    var onDone: (String) -> Void
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) var dismiss
    @Environment(\.palette) var p
    @State private var bodyText = ""
    @State private var roomId = ""
    @State private var when = Date().addingTimeInterval(3600)
    @State private var picking = false
    @FocusState private var focus: Bool

    var room: RoomItem? { store.rooms.first { $0.id == roomId } }
    var ready: Bool { !bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && room != nil }
    var finalTitle: String { NoteText.titleFrom(bodyText) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $bodyText).focused($focus).scrollContentBackground(.hidden).padding(.horizontal, 12)
                        .accessibilityIdentifier("promptText")
                    if bodyText.isEmpty { Text("Write your prompt").foregroundColor(.secondary).padding(.horizontal, 17).padding(.vertical, 8).allowsHitTesting(false) }
                }
                VStack(spacing: 10) {
                    if picking {
                        DatePicker("Send at", selection: $when, in: Date()..., displayedComponents: [.date, .hourAndMinute]).tint(notesYellow)
                        Text("Sends at this time while NeedsMe is open. Closed app sending comes with the server wake.")
                            .font(.footnote).foregroundColor(p.soft).accessibilityIdentifier("scheduleNote")
                    }
                    HStack(spacing: 10) {
                        Menu {
                            ForEach(store.rooms) { r in Button(r.title) { roomId = r.id } }
                        } label: {
                            HStack(spacing: 4) { Image(systemName: "bubble.left.and.bubble.right"); Text(room?.title ?? "Choose a room").lineLimit(1) }
                                .font(.subheadline.bold()).padding(.horizontal, 12).padding(.vertical, 9).background(p.chip).clipShape(Capsule())
                        }.accessibilityIdentifier("promptRoom")
                        Button { withAnimation { picking.toggle() } } label: {
                            HStack(spacing: 4) { Image(systemName: "clock"); Text(picking ? "Hide" : "Time") }
                                .font(.subheadline.bold()).padding(.horizontal, 12).padding(.vertical, 9).background(p.chip).clipShape(Capsule())
                        }.accessibilityIdentifier("promptTime")
                        Spacer()
                    }
                    HStack(spacing: 10) {
                        Button("Schedule") {
                            store.savePrompt(id: prompt?.id, title: finalTitle, body: bodyText, room: room, sendNow: false, at: when)
                            onDone("Scheduled."); dismiss()
                        }.buttonStyle(SoftButton()).disabled(!ready).accessibilityIdentifier("promptSchedule")
                        Button("Send now") {
                            store.savePrompt(id: prompt?.id, title: finalTitle, body: bodyText, room: room, sendNow: true, at: when)
                            onDone("Sent."); dismiss()
                        }.buttonStyle(PrimaryButton()).disabled(!ready).accessibilityIdentifier("promptSendNow")
                    }
                }.foregroundColor(p.ink).padding(.horizontal, 16).padding(.vertical, 12).background(.bar)
            }
            .background(Color(.systemBackground).ignoresSafeArea())
            .navigationTitle("").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { HStack(spacing: 2) { Image(systemName: "chevron.left"); Text("Notes") } }.tint(notesYellow)
                }
                ToolbarItem(placement: .confirmationAction) { Button("Done") { focus = false }.tint(notesYellow).bold() }
            }
            .onAppear {
                if prompt == nil, roomId.isEmpty { roomId = store.rooms.first?.id ?? "" }
                if let n = prompt {
                    bodyText = n.body; roomId = n.room
                    if let at = n.scheduledFor, at > Date() { when = at }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { focus = (prompt == nil) }
            }
        }
    }
}
