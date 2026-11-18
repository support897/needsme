import SwiftUI
import UniformTypeIdentifiers

/// Bring projects in from an AI's own data export. No AI hands its projects out through an ordinary
/// key, so this is the real way in: the person downloads the export from that AI and picks the file here.
/// Claude's export holds projects.json (a list with name and description). A plain list of
/// {"name", "description"} works too. Everything is read on this phone, never sent anywhere.
enum ProjectImport {
    struct Found: Equatable { let name: String; let about: String }

    /// Pure reader. Returns every project it can name, in file order, without repeats.
    static func parse(_ data: Data) -> [Found] {
        guard let any = try? JSONSerialization.jsonObject(with: data) else { return [] }
        var list: [[String: Any]] = []
        if let a = any as? [[String: Any]] { list = a }
        else if let d = any as? [String: Any] {
            for k in ["projects", "data", "items"] { if let a = d[k] as? [[String: Any]] { list = a; break } }
        }
        var seen = Set<String>(); var out: [Found] = []
        for x in list {
            if x["mapping"] != nil || x["chat_messages"] != nil { continue }
            let name = ((x["name"] ?? x["title"]) as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if name.isEmpty || seen.contains(name.lowercased()) { continue }
            seen.insert(name.lowercased())
            let about = ((x["description"] ?? x["prompt_template"]) as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            out.append(Found(name: name, about: about))
        }
        return out
    }

    /// Chat titles from an export: ChatGPT conversations.json (items carry "mapping"), or any list with "title" and "mapping".
    static func parseChats(_ data: Data) -> [String] {
        guard let any = try? JSONSerialization.jsonObject(with: data), let list = any as? [[String: Any]] else { return [] }
        return list.compactMap { x in
            guard x["mapping"] != nil || x["chat_messages"] != nil else { return nil }
            let t = ((x["title"] ?? x["name"]) as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? nil : t
        }
    }

    static let sample = #"[{"name":"Website launch","description":"Everything for the launch."},{"name":"Blog posts","description":""},{"name":"Pricing","description":"Monthly and yearly."},{"name":"Blog posts","description":"duplicate"}]"#
}

struct ProjectImportCard: View {
    @EnvironmentObject var store: Store
    @Environment(\.palette) var p
    @State private var picking = false
    @State private var line = ""

    func bring(_ data: Data, source: String) {
        let found = ProjectImport.parse(data)
        let chats = ProjectImport.parseChats(data)
        if found.isEmpty && !chats.isEmpty { line = DoorFiler.file(store, source: source, projects: [], chats: chats); return }
        if found.isEmpty { line = "No projects found in that file. Pick the projects.json from the export."; return }
        let have = Set(store.projects.map { $0.lowercased() })
        var added: [String] = []; var already = 0
        for f in found {
            if have.contains(f.name.lowercased()) { already += 1; continue }
            _ = store.saveNote(id: nil, title: f.name, body: f.about.isEmpty ? "Brought in from \(source)." : f.about, isPrompt: false,
                               extra: ["projects": [f.name], "project": f.name, "projectFixed": true])
            added.append(f.name)
        }
        line = "Found \(found.count) projects. Brought in \(added.count)" + (already > 0 ? ", \(already) already here." : ".")
            + (added.isEmpty ? "" : " " + added.joined(separator: ", "))
    }

    var body: some View {
        Card {
            Text("BRING PROJECTS IN").font(.caption.monospaced().bold()).foregroundColor(p.soft)
            Text("Take your projects out of an AI").font(.title3.bold()).foregroundColor(p.ink)
            Text("An AI key cannot list your projects. So download your export from the AI (Claude: Settings, Privacy, Export data), then pick its projects file here. It is read on this phone only.")
                .font(.subheadline).foregroundColor(p.soft)
            Button("Choose the export file") { picking = true }.buttonStyle(SoftButton()).accessibilityIdentifier("importProjects")
            if CommandLine.arguments.contains("-uitest-importsample") {
                Button("Use the sample file") { bring(Data(ProjectImport.sample.utf8), source: "a sample") }
                    .buttonStyle(SoftButton()).accessibilityIdentifier("importSample")
            }
            if !line.isEmpty { Text(line).font(.footnote.weight(.semibold)).foregroundColor(p.ink).accessibilityIdentifier("importResult") }
        }
        .fileImporter(isPresented: $picking, allowedContentTypes: [.json, .plainText]) { r in
            guard case .success(let url) = r else { return }
            let ok = url.startAccessingSecurityScopedResource(); defer { if ok { url.stopAccessingSecurityScopedResource() } }
            if let d = try? Data(contentsOf: url) { bring(d, source: "your export") } else { line = "Could not read that file." }
        }
    }
}
