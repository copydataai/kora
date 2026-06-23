# Kora Workflow Scheme CI And Signing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make build/test workflow reproducible from the command line and ensure unit/UI test inclusion is intentional.

**Architecture:** Add a minimal CI workflow and document the same commands locally. Wire `koraUITests` into the shared scheme after replacing template UI tests with one launch smoke test. Keep signing local by default, and use `CODE_SIGNING_ALLOWED=NO` for CI validation; this has been verified to build the app and widget locally.

**Tech Stack:** Xcode schemes, GitHub Actions on macOS, XCTest, Swift Testing.

---

## Files

- Modify: `kora.xcodeproj/xcshareddata/xcschemes/kora.xcscheme`
- Modify: `koraUITests/koraUITests.swift`
- Delete: `koraUITests/koraUITestsLaunchTests.swift`
- Create: `.github/workflows/ci.yml`
- Modify: `README.md`

## Prerequisite

Apply `docs/superpowers/plans/2026-06-23-kora-clean-test-isolation.md` first. The CI unit-test command intentionally uses clean DerivedData, so it will keep failing until the actor-isolation test fix is in place.

### Task 1: Replace Template UI Tests With A Smoke Test

- [ ] **Step 1: Replace `koraUITests/koraUITests.swift`**

Use this complete file:

```swift
import XCTest

final class KoraUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunchShowsMainWindow() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["No track selected"].waitForExistence(timeout: 5))
    }
}
```

- [ ] **Step 2: Delete screenshot/performance template test file**

Delete `koraUITests/koraUITestsLaunchTests.swift`.

- [ ] **Step 3: Run UI target directly before scheme wiring**

```bash
xcodebuild test -project kora.xcodeproj -scheme kora -destination 'platform=macOS' -only-testing:koraUITests
```

Expected before scheme wiring: FAIL saying `koraUITests` is not a member of the specified test plan or scheme.

### Task 2: Wire UI Tests Into Shared Scheme

- [ ] **Step 1: Add `koraUITests` to `kora.xcscheme`**

In `kora.xcodeproj/xcshareddata/xcschemes/kora.xcscheme`, add this `TestableReference` after the existing `koraTests` testable:

```xml
         <TestableReference
            skipped = "NO">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "13D589672FE9206800422F48"
               BuildableName = "koraUITests.xctest"
               BlueprintName = "koraUITests"
               ReferencedContainer = "container:kora.xcodeproj"
               BuildableProductType = "com.apple.product-type.bundle.ui-testing">
            </BuildableReference>
         </TestableReference>
```

- [ ] **Step 2: Verify full scheme tests locally**

```bash
rm -rf /tmp/kora-scheme-tests
xcodebuild test -project kora.xcodeproj -scheme kora -destination 'platform=macOS' -derivedDataPath /tmp/kora-scheme-tests
```

Expected: unit tests and `KoraUITests.testLaunchShowsMainWindow` run; command ends with `** TEST SUCCEEDED **`.

### Task 3: Add CI Workflow

- [ ] **Step 1: Create `.github/workflows/ci.yml`**

```yaml
name: CI

on:
  pull_request:
  push:
    branches:
      - main

jobs:
  build-and-test:
    runs-on: macos-15
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode.app

      - name: Build
        run: |
          xcodebuild build \
            -project kora.xcodeproj \
            -scheme kora \
            -destination 'platform=macOS,arch=arm64' \
            -derivedDataPath /tmp/kora-ci-build \
            CODE_SIGNING_ALLOWED=NO

      - name: Unit tests
        run: |
          xcodebuild test \
            -project kora.xcodeproj \
            -scheme kora \
            -destination 'platform=macOS,arch=arm64' \
            -derivedDataPath /tmp/kora-ci-tests \
            -only-testing:koraTests \
            CODE_SIGNING_ALLOWED=NO
```

- [ ] **Step 2: Verify CI commands locally**

```bash
xcodebuild build -project kora.xcodeproj -scheme kora -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/kora-ci-build CODE_SIGNING_ALLOWED=NO
xcodebuild test -project kora.xcodeproj -scheme kora -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/kora-ci-tests -only-testing:koraTests CODE_SIGNING_ALLOWED=NO
```

Expected after the clean-test-isolation plan is applied: both commands succeed. Before that plan is applied, the unit test command fails with main actor isolation errors in `LibraryScanTests.swift`.

### Task 4: Document Workflow And Signing

- [ ] **Step 1: Add CLI commands to `README.md`**

Under `## Build & run`, add:

````markdown
CLI build:

```bash
xcodebuild build -project kora.xcodeproj -scheme kora -destination 'platform=macOS'
```

CLI tests:

```bash
xcodebuild test -project kora.xcodeproj -scheme kora -destination 'platform=macOS'
```

CI runs build and unit tests with `CODE_SIGNING_ALLOWED=NO`. Full UI tests are part of the shared scheme and should be run locally on a signed development machine.
````

- [ ] **Step 2: Commit workflow changes**

```bash
git add .github/workflows/ci.yml README.md koraUITests kora.xcodeproj/xcshareddata/xcschemes/kora.xcscheme
git commit -m "ci: add reproducible Kora build and test workflow"
```
