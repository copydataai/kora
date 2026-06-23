import Foundation
import AVFoundation

struct Track: Identifiable, Hashable {
    let id: UUID
    let url: URL
    let folderID: UUID
    var title: String
    var artist: String?

    init(url: URL, folderID: UUID, title: String? = nil, artist: String? = nil) {
        self.id = UUID()
        self.url = url
        self.folderID = folderID
        self.title = title ?? url.deletingPathExtension().lastPathComponent
        self.artist = artist
    }

    func loadMetadata() async -> (title: String, artist: String?) {
        let asset = AVURLAsset(url: url)
        guard let items = try? await asset.load(.commonMetadata) else { return (title, artist) }
        let loadedTitle = await stringValue(items, .commonKeyTitle)
        let loadedArtist = await stringValue(items, .commonKeyArtist)
        return (loadedTitle ?? title, loadedArtist ?? artist)
    }

    func loadArtwork() async -> Data? {
        let asset = AVURLAsset(url: url)
        guard let items = try? await asset.load(.commonMetadata) else { return nil }
        for item in items where item.commonKey == .commonKeyArtwork {
            if let data = try? await item.load(.dataValue) { return data }
        }
        return nil
    }

    private func stringValue(_ items: [AVMetadataItem], _ key: AVMetadataKey) async -> String? {
        for item in items where item.commonKey == key {
            if let s = try? await item.load(.stringValue), !s.isEmpty { return s }
        }
        return nil
    }
}
