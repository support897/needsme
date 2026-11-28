import SwiftUI

/// The AIs you have open, like browser tabs. Grouped by AI, saved on this phone.
@MainActor
final class OpenTabs: ObservableObject {
    static let shared = OpenTabs()
    @Published private(set) var ids: [String] = UserDefaults.standard.stringArray(forKey: "needsme.openTabs") ?? []
    private func save() { UserDefaults.standard.set(ids, forKey: "needsme.openTabs"); UserDefaults.standard.set(Array(seen), forKey: "needsme.seenAccounts") }
    /// Every account you have ever opened, even if its tab is closed now.
    @Published private(set) var seen: Set<String> = Set(UserDefaults.standard.stringArray(forKey: "needsme.seenAccounts") ?? [])

    private func rank(_ id: String) -> Int {
        guard let a = AIConnections.shared.account(id) else { return 999 }
        return webCatalog.firstIndex { $0.id == a.provider } ?? 998
    }
    func open(_ a: AIAccount) {
        if !ids.contains(a.id) { ids.append(a.id) }
        seen.insert(a.id)
        ids = ids.enumerated().sorted { (rank($0.element), $0.offset) < (rank($1.element), $1.offset) }.map { $0.element }
        save()
    }
    func markSeen(_ id: String) { if !seen.contains(id) { seen.insert(id); save() } }
    func close(_ id: String) { ids.removeAll { $0 == id }; save() }
    /// Open tabs that still exist.
    var accounts: [AIAccount] { ids.compactMap { AIConnections.shared.account($0) } }
}

/// Pick another AI to open as a new tab. Type to search.
struct AddTabSheet: View {
    var onPick: (AIAccount) -> Void
    @Environment(\.dismiss) var dismiss
    @Environment(\.palette) var p
    @ObservedObject private var conns = AIConnections.shared
    @ObservedObject private var tabs = OpenTabs.shared
    @State private var query = ""
    @State private var name = ""
    @State private var link = ""
    @FocusState private var focus: Bool

    func match(_ s: String) -> Bool { query.isEmpty || s.localizedCaseInsensitiveContains(query) }
    var mine: [AIAccount] { conns.mine.filter { match($0.label) } }
    var groups: [String] { webCatalog.map { $0.group }.reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } } }

    func pick(_ w: WebAI) {
        let a = conns.accounts(forId: w.id).first ?? conns.addWeb(id: w.id, label: "")
        onPick(a); dismiss()
    }

    var body: some View {
        NavigationStack {
            List {
                if !mine.isEmpty {
                    Section("Your accounts") {
                        ForEach(mine) { a in
                            Button { onPick(a); dismiss() } label: { HStack(spacing: 12) { AIFace(label: a.label, size: 30)
                                VStack(alignment: .leading, spacing: 1) { Text(a.label).foregroundColor(p.ink); Text(a.platformName).font(.caption).foregroundColor(p.soft) }
                                Spacer()
                                if tabs.ids.contains(a.id) { Text("Open").font(.caption.bold()).foregroundColor(p.soft) }
                                else if conns.isConnected(a) { Circle().fill(Color.sprout).frame(width: 9, height: 9) } } }
                        }
                    }
                    Section { EmptyView() } header: { Text("More AIs to add").font(.footnote.bold()).foregroundColor(p.soft).textCase(nil) }
                }
                ForEach(groups, id: \.self) { g in
                    let items = webCatalog.filter { $0.group == g && !$0.url.isEmpty && match($0.name) }
                    if !items.isEmpty {
                        Section(g) {
                            ForEach(items) { w in
                                Button { pick(w) } label: {
                                    HStack(spacing: 12) { AIFace(label: w.name, size: 30); Text(w.name).foregroundColor(p.ink); Spacer()
                                        if conns.accounts(forId: w.id).contains(where: { conns.isConnected($0) }) { Image(systemName: "checkmark").foregroundColor(.sprout) } }
                                }
                            }
                        }
                    }
                }
                if query.isEmpty {
                    Section("Any other AI") {
                        TextField("Name", text: $name)
                        TextField("Web address, like chat.example.com", text: $link).textInputAutocapitalization(.never).keyboardType(.URL).autocorrectionDisabled()
                        Button("Add and open") {
                            var u = link.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !u.isEmpty && !u.hasPrefix("http") { u = "https://" + u }
                            if URL(string: u)?.host != nil { onPick(conns.addWeb(id: "custom", label: name.isEmpty ? "Other AI" : name, url: u)); dismiss() }
                        }.disabled(link.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search AIs")
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Open an AI").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        }
    }
}

/// One tab: the AI's face and name, with a small close mark.
struct TabChip: View {
    let account: AIAccount
    let selected: Bool
    var onTap: () -> Void
    var onClose: () -> Void
    @Environment(\.palette) var p
    var body: some View {
        HStack(spacing: 6) {
            Button(action: onTap) {
                HStack(spacing: 6) {
                    AIFace(label: account.label, size: 22)
                    Text(account.label).font(.system(size: 13, weight: selected ? .bold : .medium)).foregroundColor(p.ink).lineLimit(1)
                }
            }.buttonStyle(.plain)
            Button(action: onClose) {
                Image(systemName: "xmark").font(.system(size: 9, weight: .bold)).foregroundColor(p.soft).frame(width: 20, height: 20)
            }.buttonStyle(.plain).accessibilityIdentifier("closeTab-" + account.label)
        }
        .padding(.leading, 8).padding(.trailing, 4).padding(.vertical, 5)
        .background(selected ? Color.sprout.opacity(0.35) : p.chip)
        .overlay(Capsule().stroke(selected ? Color.sprout : Color.clear, lineWidth: 1.5))
        .clipShape(Capsule())
    }
}
