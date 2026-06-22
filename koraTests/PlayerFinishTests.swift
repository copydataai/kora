import Testing
import Foundation
@testable import kora

struct PlayerFinishTests {
    @Test func advancesOnNaturalFinish() {
        // was playing, player stopped itself at end -> advance
        #expect(MusicPlayer.shouldAdvanceOnFinish(wasPlaying: true, isPlayerPlaying: false, currentTime: 100, duration: 100))
    }
    @Test func doesNotAdvanceOnManualPauseNearEnd() {
        // user paused (our isPlaying already false) within last 0.25s -> must NOT advance
        #expect(!MusicPlayer.shouldAdvanceOnFinish(wasPlaying: false, isPlayerPlaying: false, currentTime: 100, duration: 100))
    }
    @Test func doesNotAdvanceMidTrack() {
        #expect(!MusicPlayer.shouldAdvanceOnFinish(wasPlaying: true, isPlayerPlaying: false, currentTime: 10, duration: 100))
    }
}
