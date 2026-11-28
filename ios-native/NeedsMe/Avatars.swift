import SwiftUI
import PhotosUI
import UIKit

/// A picture or icon for each AI account. Saved on this phone only.
@MainActor
final class AvatarStore: ObservableObject {
    static let shared = AvatarStore()
    @Published var tick = 0
    private let key = "needsme.avatars"
    private var map: [String: String] { (UserDefaults.standard.dictionary(forKey: key) as? [String: String]) ?? [:] }
    private func save(_ m: [String: String]) { UserDefaults.standard.set(m, forKey: key); tick += 1 }
    private func file(_ id: String) -> URL { FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("avatar-\(id).jpg") }

    func symbol(_ id: String) -> String? { let v = map[id]; return v?.hasPrefix("sf:") == true ? String(v!.dropFirst(3)) : nil }
    func image(_ id: String) -> UIImage? { map[id] == "img" ? UIImage(contentsOfFile: file(id).path) : nil }
    func emoji(_ id: String) -> String? { let v = map[id]; return v?.hasPrefix("em:") == true ? String(v!.dropFirst(3)) : nil }
    func setEmoji(_ s: String, _ id: String) { guard let c = s.first else { return }; var m = map; m[id] = "em:" + String(c); save(m) }
    private let dkey = "needsme.avatarDesc"
    func desc(_ id: String) -> String { ((UserDefaults.standard.dictionary(forKey: dkey) as? [String: String]) ?? [:])[id] ?? "" }
    func setDesc(_ s: String, _ id: String) {
        var d = (UserDefaults.standard.dictionary(forKey: dkey) as? [String: String]) ?? [:]
        d[id] = String(s.prefix(60)); UserDefaults.standard.set(d, forKey: dkey); tick += 1
    }
    private let ckey = "needsme.avatarColor"
    func colorHex(_ id: String) -> Int? { ((UserDefaults.standard.dictionary(forKey: ckey) as? [String: Int]) ?? [:])[id] }
    func color(_ id: String) -> Color? { colorHex(id).map { Color(hex: UInt32($0)) } }
    func setColorHex(_ h: Int?, _ id: String) {
        var d = (UserDefaults.standard.dictionary(forKey: ckey) as? [String: Int]) ?? [:]
        d[id] = h; UserDefaults.standard.set(d, forKey: ckey); tick += 1
    }
    /// Light colors need dark marks on top, dark colors need light ones.
    func isLight(_ h: Int) -> Bool { let r = Double((h >> 16) & 255), g = Double((h >> 8) & 255), b = Double(h & 255); return (0.299 * r + 0.587 * g + 0.114 * b) > 150 }
    private let pkey = "needsme.avatarPrompted"
    func shouldPrompt(_ id: String) -> Bool {
        let done = Set(UserDefaults.standard.stringArray(forKey: pkey) ?? [])
        if done.contains(id) { return false }
        UserDefaults.standard.set(Array(done.union([id])), forKey: pkey)
        return !has(id) && desc(id).isEmpty && colorHex(id) == nil
    }
    func has(_ id: String) -> Bool { map[id] != nil }
    /// Changes when the picture changes (size of the saved file), so the shared list knows to send it.
    func imageStamp(_ id: String) -> Int {
        guard map[id] == "img", let at = try? FileManager.default.attributesOfItem(atPath: file(id).path) else { return 0 }
        return (at[.size] as? Int) ?? 0
    }
    func setSymbol(_ s: String, _ id: String) { var m = map; m[id] = "sf:" + s; save(m) }
    func setImage(_ img: UIImage, _ id: String) {
        let side: CGFloat = 256
        let r = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))
        let small = r.image { _ in
            let s = max(side / img.size.width, side / img.size.height)
            let w = img.size.width * s, h = img.size.height * s
            img.draw(in: CGRect(x: (side - w) / 2, y: (side - h) / 2, width: w, height: h))
        }
        try? small.jpegData(compressionQuality: 0.85)?.write(to: file(id))
        var m = map; m[id] = "img"; save(m)
    }
    func clear(_ id: String) { var m = map; m[id] = nil; try? FileManager.default.removeItem(at: file(id)); save(m) }
    /// Look up by the label shown in the app.
    func accountId(forLabel l: String) -> String? { AIConnections.shared.accounts.first { $0.label == l }?.id }
}

let avatarSymbols = ["sparkles", "brain.head.profile", "bolt", "leaf", "flame", "moon", "sun.max", "star", "heart", "hare", "pawprint", "cube", "atom", "globe", "briefcase", "hammer", "book", "music.note", "camera", "paintbrush", "graduationcap", "cart", "house", "scope"]

/// Edit the name and icon of one account.
struct AccountEditor: View {
    let account: AIAccount
    @Environment(\.dismiss) var dismiss
    @Environment(\.palette) var p
    @ObservedObject private var conns = AIConnections.shared
    @ObservedObject private var av = AvatarStore.shared
    @State private var name = ""
    @State private var about = ""
    @State private var emojiText = ""
    @State private var photo: PhotosPickerItem?
    @State private var confirmRemove = false
    var onRemoved: () -> Void = {}

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    AIFace(label: conns.account(account.id)?.label ?? account.label, size: 84).id(av.tick)
                    TextField("Nickname", text: $name).textFieldStyle(.roundedBorder).accessibilityIdentifier("acctName")
                    TextField("Short description (optional)", text: $about).textFieldStyle(.roundedBorder).accessibilityIdentifier("acctAbout")
                    Text("Color").font(.headline).foregroundColor(p.ink).frame(maxWidth: .infinity, alignment: .leading)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach([0xA8C256, 0x16120E, 0xF0EAE0, 0xE5484D, 0xF5A524, 0xF2D14B, 0x2FBF71, 0x2BB7C8, 0x3E7BFA, 0x7C5CFA, 0xD64FB0, 0x8B6B4A], id: \.self) { h in
                                Button { av.setColorHex(h, account.id) } label: {
                                    Circle().fill(Color(hex: UInt32(h))).frame(width: 38, height: 38)
                                        .overlay(Circle().stroke(av.colorHex(account.id) == h ? p.ink : p.soft.opacity(0.3), lineWidth: av.colorHex(account.id) == h ? 3 : 1))
                                }.buttonStyle(.plain)
                            }
                        }
                    }
                    ColorPicker("Any color you like", selection: Binding(
                        get: { av.color(account.id) ?? Color.sprout },
                        set: { c in var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0; UIColor(c).getRed(&r, green: &g, blue: &b, alpha: &a)
                               av.setColorHex((Int(r * 255) << 16) | (Int(g * 255) << 8) | Int(b * 255), account.id) }), supportsOpacity: false)
                        .font(.subheadline).foregroundColor(p.ink)
                    if av.colorHex(account.id) != nil { Button("Remove color") { av.setColorHex(nil, account.id) }.font(.footnote) }
                    Text("Emoji").font(.headline).foregroundColor(p.ink).frame(maxWidth: .infinity, alignment: .leading)
                    HStack {
                        TextField("Type or paste one", text: $emojiText).textFieldStyle(.roundedBorder)
                            .onChange(of: emojiText) { v in if let c = v.last { av.setEmoji(String(c), account.id); emojiText = String(c) } }
                        Text(av.emoji(account.id) ?? "").font(.system(size: 30))
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(["🙂", "🤖", "🧠", "⚡️", "🌱", "🔥", "🌙", "⭐️", "🦊", "🐙", "🎯", "💡", "🚀", "🎨", "📚", "🛠"], id: \.self) { e in
                                Button { av.setEmoji(e, account.id) } label: { Text(e).font(.system(size: 26)).frame(width: 46, height: 46)
                                    .background(av.emoji(account.id) == e ? Color.sprout : p.chip).clipShape(Circle()) }.buttonStyle(.plain)
                            }
                        }
                    }
                    Text("Or pick an icon").font(.headline).foregroundColor(p.ink).frame(maxWidth: .infinity, alignment: .leading)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(avatarSymbols, id: \.self) { s in
                            Button { av.setSymbol(s, account.id) } label: {
                                Image(systemName: s).font(.system(size: 20)).foregroundColor(p.ink)
                                    .frame(width: 46, height: 46).background(av.symbol(account.id) == s ? Color.sprout : p.chip).clipShape(Circle())
                            }.buttonStyle(.plain)
                        }
                    }
                    PhotosPicker(selection: $photo, matching: .images) { Label("Use a photo", systemImage: "photo") }.buttonStyle(SoftButton())
                    if av.has(account.id) { Button("Back to the default icon") { av.clear(account.id) }.buttonStyle(SoftButton()) }
                    Text("Tip: a photo can be any picture from your library.").font(.footnote).foregroundColor(p.soft)
                    AlertTicks(id: account.id).padding(.top, 8)
                    Button(role: .destructive) { confirmRemove = true } label: { Text("Remove this account") }.padding(.top, 8)
                }.padding()
            }
            .scrollDismissesKeyboard(.interactively)
            .lookBg().navigationTitle("Edit account").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") {
                if !name.trimmingCharacters(in: .whitespaces).isEmpty { conns.rename(account, to: name) }; av.setDesc(about, account.id); dismiss() } } }
            .onAppear { name = account.label; about = av.desc(account.id) }
            .onChange(of: photo) { item in
                Task { if let d = try? await item?.loadTransferable(type: Data.self), let i = UIImage(data: d) { av.setImage(i, account.id) } }
            }
            .alert("Remove \(account.label)?", isPresented: $confirmRemove) {
                Button("Remove", role: .destructive) { conns.remove(account); av.clear(account.id); onRemoved(); dismiss() }
                Button("Cancel", role: .cancel) {}
            } message: { Text("Its saved login on this phone is deleted.") }
        }
    }
}

/// Instagram-style row: tap a face to open that account.
struct AccountSwitcher: View {
    let accounts: [AIAccount]
    var current: String? = nil
    var onPick: (AIAccount) -> Void
    var onPlus: (() -> Void)? = nil
    @Environment(\.palette) var p
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(accounts) { a in
                    Button { onPick(a) } label: {
                        VStack(spacing: 4) {
                            AIFace(label: a.label, size: 46)
                                .padding(3).overlay(Circle().stroke(current == a.id ? Color.sprout : Color.clear, lineWidth: 2.5))
                            Text(a.label).font(.system(size: 11, weight: current == a.id ? .bold : .medium)).foregroundColor(p.ink).lineLimit(1).frame(width: 62)
                        }
                    }.buttonStyle(.plain).accessibilityIdentifier("switch-" + a.label)
                }
                if let onPlus {
                    Button(action: onPlus) {
                        VStack(spacing: 4) {
                            Image(systemName: "plus").font(.system(size: 18, weight: .bold)).foregroundColor(p.soft)
                                .frame(width: 46, height: 46).overlay(Circle().stroke(Color.faint.opacity(0.7), lineWidth: 1)).padding(3)
                            Text("Add").font(.system(size: 11)).foregroundColor(p.soft)
                        }
                    }.buttonStyle(.plain)
                }
            }.padding(.horizontal, 14)
        }
    }
}

/// A small button that appears with the keyboard and puts it away.
struct KeyboardDownButton: View {
    @State private var up = false
    var body: some View {
        Group {
            if up {
                Button {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    WebHub.blurAll()
                } label: {
                    Image(systemName: "keyboard.chevron.compact.down").font(.system(size: 18, weight: .semibold)).foregroundColor(.loam)
                        .frame(width: 46, height: 38).background(Color.sprout).clipShape(Capsule()).shadow(radius: 4, y: 2)
                }.accessibilityIdentifier("keyboardDown").padding(10)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in up = true }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in up = false }
    }
}
