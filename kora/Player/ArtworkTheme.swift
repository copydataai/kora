import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

nonisolated struct ArtworkTheme: Equatable {
    var accent: Color
    var textPrimary: Color
    var artwork: Data?

    static let neutral = ArtworkTheme(accent: .accentColor, textPrimary: .primary, artwork: nil)
}

nonisolated enum ArtworkPalette {
    /// Relative luminance threshold: bright average artwork wants dark text on top.
    static func useDarkText(r: Double, g: Double, b: Double) -> Bool {
        let luminance = 0.299 * r + 0.587 * g + 0.114 * b   // 0...1
        return luminance > 0.6
    }

    static func theme(forAverage r: Double, g: Double, b: Double, artwork: Data?) -> ArtworkTheme {
        ArtworkTheme(
            accent: Color(.sRGB, red: r, green: g, blue: b, opacity: 1),
            textPrimary: useDarkText(r: r, g: g, b: b) ? .black : .white,
            artwork: artwork
        )
    }

    /// Decodes artwork, averages it with CIAreaAverage, and builds a theme.
    /// Returns `.neutral` for missing/undecodable artwork. Runs off the main actor.
    static func theme(for data: Data?) async -> ArtworkTheme {
        guard let data, let avg = averageRGBA(of: data) else { return .neutral }
        return theme(forAverage: avg.r, g: avg.g, b: avg.b, artwork: data)
    }

    private static func averageRGBA(of data: Data) -> (r: Double, g: Double, b: Double)? {
        guard let image = CIImage(data: data) else { return nil }
        let filter = CIFilter.areaAverage()
        filter.inputImage = image
        filter.extent = image.extent
        guard let output = filter.outputImage else { return nil }

        var bitmap = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: [.workingColorSpace: NSNull()])
        context.render(
            output,
            toBitmap: &bitmap,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )
        return (Double(bitmap[0]) / 255, Double(bitmap[1]) / 255, Double(bitmap[2]) / 255)
    }
}
