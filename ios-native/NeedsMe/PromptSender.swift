import SwiftUI

/// Posts a prompt into its room as her message, and wakes the room the normal way.
/// If that room is open, its own engine does it. If not, a short lived engine does it and is retired
/// when she opens the room, or after five minutes.
@MainActor
enum PromptSender {
    static func post(store: Store, roomId: String, text: String) {
        if let e = RoomEngine.live[roomId] { e.send(text); return }
        guard let room = store.rooms.first(where: { $0.id == roomId }) else { return }
        let e = RoomEngine(store: store, room: room)
        e.isBackground = true
        e.start()
        e.send(text)
        Task {
            try? await Task.sleep(nanoseconds: 300_000_000_000)
            if RoomEngine.live[roomId] === e { e.close() }
        }
    }
}
