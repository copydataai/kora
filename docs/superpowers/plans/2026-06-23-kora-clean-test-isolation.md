# Kora Clean Test Isolation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `xcodebuild test` pass from clean DerivedData under the current Swift actor isolation settings.

**Architecture:** Preserve the current app behavior and fix the tests at the isolation boundary. Tests that touch app-target types isolated by `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` run on `@MainActor`; pure static tests remain nonisolated.

**Tech Stack:** Swift Testing, XCTest UI tests, Xcode 26 project settings.

---

## Files

- Modify: `koraTests/LibraryScanTests.swift`
- Modify: `koraTests/PlayQueueTests.swift`
- Modify: `koraTests/PlayerFinishTests.swift`
- Delete: `koraTests/koraTests.swift`

### Task 1: Reproduce The Clean Failure

- [ ] **Step 1: Run clean tests**

```bash
rm -rf /tmp/kora-clean-tests
xcodebuild test -project kora.xcodeproj -scheme kora -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/kora-clean-tests
```

Expected: FAIL with main actor isolation errors in `LibraryScanTests.swift` and/or `PlayQueueTests.swift`.

### Task 2: Fix Unit Test Actor Isolation

- [ ] **Step 1: Mark app-type tests as `@MainActor`**

In `koraTests/LibraryScanTests.swift`, change only `trackTitleDefaultsToFilename`:

```swift
@Test @MainActor func trackTitleDefaultsToFilename() {
    let t = Track(url: URL(fileURLWithPath: "/m/Song Name.m4a"), folderID: UUID())
    #expect(t.title == "Song Name")
    #expect(t.artist == nil)
}
```

In `koraTests/PlayQueueTests.swift`, update the helper and all tests:

```swift
@MainActor
private func track(_ name: String) -> Track {
    Track(url: URL(fileURLWithPath: "/tmp/\(name).mp3"), folderID: UUID())
}

struct PlayQueueTests {
    @Test @MainActor func startsAtRequestedIndex() {
        var q = PlayQueue(tracks: [track("a"), track("b"), track("c")], startAt: 1)
        #expect(q.current?.title == "b")
    }

    @Test @MainActor func nextAdvancesAndStopsAtEnd() {
        var q = PlayQueue(tracks: [track("a"), track("b")], startAt: 0)
        #expect(q.next()?.title == "b")
        #expect(q.next() == nil)
        #expect(q.current?.title == "b")
    }

    @Test @MainActor func previousStepsBackAndStopsAtStart() {
        var q = PlayQueue(tracks: [track("a"), track("b")], startAt: 1)
        #expect(q.previous()?.title == "a")
        #expect(q.previous() == nil)
        #expect(q.current?.title == "a")
    }

    @Test @MainActor func emptyQueueHasNoCurrent() {
        var q = PlayQueue(tracks: [], startAt: 0)
        #expect(q.current == nil)
        #expect(q.next() == nil)
    }
}
```

In `koraTests/PlayerFinishTests.swift`, mark tests as `@MainActor` if the compiler reports isolation errors for `MusicPlayer.shouldAdvanceOnFinish`.

- [ ] **Step 2: Delete empty template unit test**

Delete `koraTests/koraTests.swift`; it adds a passing test with no intent.

- [ ] **Step 3: Run clean unit tests**

```bash
rm -rf /tmp/kora-clean-tests
xcodebuild test -project kora.xcodeproj -scheme kora -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/kora-clean-tests
```

Expected: `Test run with 11 tests` or `12 tests` depending on whether UI tests have already been wired into the scheme, and `** TEST SUCCEEDED **`.

### Task 3: Commit

- [ ] **Step 1: Commit test isolation fix**

```bash
git add koraTests
git commit -m "test: make clean Swift tests actor-safe"
```

