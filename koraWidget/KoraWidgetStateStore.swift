import Foundation

enum NowPlayingStore {
    static func read() -> NowPlayingSnapshot? {
        guard let url = NowPlayingSharedStore.containerURL(),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(NowPlayingSnapshot.self, from: data)
    }
}
