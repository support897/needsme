import SwiftUI

let aiNames = ["Claude", "ChatGPT", "Gemini", "Grok", "Perplexity", "Copilot"]

struct NotesView: View {
    @EnvironmentObject var store: Store
    @Environment(\.palette) var p
    @State private var showPrompts = false
    @State private var query = ""
    @State private var filter = ""
    @State private var editing: NoteItem?
    @State private var creating = false
    @State private var toast = ""

    var shown: [NoteItem] {
        store.notes.filter { $0.isPrompt == showPrompts && (filter.isEmpty || $0.project == filter)
            && (query.isEmpty || ($0.title + $0.body).localizedCaseInsensitiveContains(query)) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Picker("", selection: $showPrompts) { Text("Notes").tag(false); Text("Prompts").tag(true) }.pickerStyle(.segmented)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            chip("All", filter.isEmpty) { filter = "" }
                            ForEach(store.projects, id: \.self) { n in chip(n, filter == n) { filter = n } }
                        }
                    }
                    if shown.isEmpty { Text(showPrompts ? "No prompts yet. Tap + to save one." : "No notes yet. Tap + to add one.").foregroundColor(p.soft) }
                    ForEach(shown) { n in
                        Card {
                            Text(n.title).font(.headline).foregroundColor(p.ink)
                            HStack { tag(n.project.isEmpty ? "Unsorted" : n.project); tag(n.ai.isEmpty ? "Any AI" : n.ai) }
                            if !n.body.isEmpty { Text(n.body).font(.subheadline).foregroundColor(p.soft) }
                            HStack {
                                if n.isPrompt { Button("Copy to use") { UIPasteboard.general.string = n.body; flash("Copied.") }.buttonStyle(PrimaryButton()) }
                                Button("Edit") { editing = n }.buttonStyle(SoftButton())
                                Button("Delete") { store.delete(n) }.buttonStyle(SoftButton())
                            }
                        }
                    }
                }.padding()
            }
            .searchable(text: $query)
            .background(p.bg).navigationTitle("Notes & prompts")
            .toolbar { Button { creating = true } label: { Image(systemName: "plus") }.accessibilityLabel("New") }
            .sheet(isPresented: $creating) { NoteEditor(note: nil, isPrompt: showPrompts) { flash("Saved.") } }
            .sheet(item: $editing) { n in NoteEditor(note: n, isPrompt: n.isPrompt) { flash("Saved.") } }
            .overlay(alignment: .bottom) {
                if !toast.isEmpty { Text(toast).padding(12).background(p.ink).foregroundColor(p.bg).clipShape(Capsule()).padding(.bottom, 12).transition(.opacity) }
            }
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

struct NoteEditor: View {
    let note: NoteItem?
    let isPrompt: Bool
    var onSaved: () -> Void
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) var dismiss
    @State private var title = ""
    @State private var bodyText = ""
    @State private var project = ""
    @State private var ai = ""

    // Looks like this belongs in <project> / is for <AI>
    var suggestedProject: String? {
        let t = (title + " " + bodyText).lowercased()
        return store.projects.first { t.contains($0.lowercased()) && $0 != project }
    }
    var suggestedAI: String? {
        let t = (title + " " + bodyText).lowercased()
        return aiNames.first { t.contains($0.lowercased()) && $0 != ai }
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $title)
                TextField(isPrompt ? "Prompt text" : "Note", text: $bodyText, axis: .vertical).lineLimit(4...10)
                if isPrompt { Text("Tip: write {{like this}} for parts you fill in each time.").font(.footnote) }
                Picker("Project", selection: $project) { Text("Unsorted").tag(""); ForEach(store.projects, id: \.self) { Text($0).tag($0) } }
                Picker("Best for which AI?", selection: $ai) { Text("Any AI").tag(""); ForEach(aiNames, id: \.self) { Text($0).tag($0) } }
                if let s = suggestedProject { Button("Looks like this belongs in \(s). Save here") { project = s } }
                if let s = suggestedAI { Button("Looks like this is for \(s). Use it") { ai = s } }
            }
            .navigationTitle(note == nil ? "New" : "Edit")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.saveNote(id: note?.id, title: title, body: bodyText, project: project, ai: ai, isPrompt: isPrompt)
                        onSaved(); dismiss()
                    }.disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if let n = note { title = n.title; bodyText = n.body; project = n.project == "Unsorted" ? "" : n.project; ai = n.ai == "Any AI" ? "" : n.ai }
            }
        }
    }
}
