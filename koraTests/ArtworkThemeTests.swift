import Testing
import SwiftUI
@testable import kora

struct ArtworkThemeTests {
    @Test func lightAverageUsesDarkText() {
        #expect(ArtworkPalette.useDarkText(r: 1, g: 1, b: 1))        // white art → black text
        #expect(ArtworkPalette.useDarkText(r: 0.9, g: 0.9, b: 0.8))
    }

    @Test func darkAverageUsesLightText() {
        #expect(!ArtworkPalette.useDarkText(r: 0, g: 0, b: 0))       // black art → white text
        #expect(!ArtworkPalette.useDarkText(r: 0.1, g: 0.1, b: 0.2))
    }

    @Test func themeFromAverageCarriesArtworkAndTextChoice() {
        let art = Data([1, 2, 3])
        let light = ArtworkPalette.theme(forAverage: 1, g: 1, b: 1, artwork: art)
        #expect(light.textPrimary == Color.black)
        #expect(light.artwork == art)

        let dark = ArtworkPalette.theme(forAverage: 0, g: 0, b: 0, artwork: art)
        #expect(dark.textPrimary == Color.white)
    }

    @Test func nilArtworkIsNeutral() async {
        let theme = await ArtworkPalette.theme(for: nil)
        #expect(theme == ArtworkTheme.neutral)
    }
}
