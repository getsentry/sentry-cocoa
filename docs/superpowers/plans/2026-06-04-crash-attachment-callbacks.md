# Crash-Time Screenshot & View Hierarchy Attachments

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire crash-time screenshot and view-hierarchy saving through KSCrash's `didWriteReportCallback`, and load those saved files as attachments on the next launch when the crash event is sent.

**Architecture:** `SentryCrashAttachmentsStorage` holds Swift closures registered by `SentryScreenshotIntegration` and `SentryViewHierarchyIntegration`. `KSCrashIntegration` sets `config.didWriteReportCallback` — already a Swift closure — to construct the per-report attachment directory and invoke those closures directly, with no C bridge needed. On the next launch, `KSCrashReportSink` reads the report ID out of each crash report dictionary, loads any files in the corresponding directory, attaches them to the copied scope, and cleans up. This is a **best-effort, always-on** attempt mirroring original SentryCrash: "since the app is already in a crash state we don't mind if this approach crashes."

**Tech Stack:** Swift, XCTest, KSCrash v2 (`KSCrashConfiguration.didWriteReportCallback`, `KSCrash_ExceptionHandlingPlan`)

---

## Background

`SentryScreenshotIntegration` and `SentryViewHierarchyIntegration` currently call `sentrycrash_setSaveScreenshots` / `sentrycrash_setSaveViewHierarchy` to register C function-pointer callbacks stored in `SentryAttachmentCallback.c` globals. Nothing ever calls those globals — the whole mechanism was stubbed out when migrating to upstream KSCrash v2.

`KSCrashConfiguration.didWriteReportCallback` is a Swift closure (`NS_SWIFT_UNAVAILABLE` on the C typedef forces the ObjC property to bridge to a Swift closure). It fires after the crash report is written with `(plan, reportID)`. Since it's already Swift, there is no reason to go through C at all — store the callbacks as Swift closures and invoke them directly.

No new C/ObjC code is added. The existing `SentryAttachmentCallback.c` stubs are left in place (already dead) and can be removed in a follow-up.

The only guard applied is `crashedDuringExceptionHandling` (we're in a double-fault; do as little as possible). `requiresAsyncSafety` is intentionally **not** guarded — original SentryCrash always ran these callbacks after writing, even from signal context.

---

## File Map

| Action | Path                                                                                     |
| ------ | ---------------------------------------------------------------------------------------- |
| Create | `Sources/Swift/Integrations/KSCrash/SentryCrashAttachmentsStorage.swift`                 |
| Modify | `Sources/Swift/Integrations/Screenshot/SentryScreenshotIntegration.swift`                |
| Modify | `Sources/Swift/Integrations/ViewHierarchy/SentryViewHierarchyIntegration.swift`          |
| Modify | `Sources/Swift/Integrations/KSCrash/KSCrashIntegration.swift`                            |
| Modify | `Sources/Swift/Integrations/KSCrash/KSCrashReportSink.swift`                             |
| Modify | `Tests/SentryTests/Integrations/Screenshot/SentryScreenshotIntegrationTests.swift`       |
| Modify | `Tests/SentryTests/Integrations/ViewHierarchy/SentryViewHierarchyIntegrationTests.swift` |
| Modify | `Tests/SentryTests/Integrations/KSCrash/KSCrashIntegrationTests.swift`                   |
| Modify | `Tests/SentryTests/Integrations/KSCrash/KSCrashReportSinkTests.swift`                    |

---

## Task 1: Create `SentryCrashAttachmentsStorage`

This enum is the single source of truth for crash-time attachment state: the install-time base path and the per-integration Swift closures.

**Files:**

- Create: `Sources/Swift/Integrations/KSCrash/SentryCrashAttachmentsStorage.swift`

- [ ] **Step 1: Create the file**

  ```swift
  // Sources/Swift/Integrations/KSCrash/SentryCrashAttachmentsStorage.swift
  @_implementationOnly import _SentryPrivate
  import Foundation

  enum SentryCrashAttachmentsStorage {
      // Set by KSCrashIntegration at install time.
      static var basePath: String?

      // Set by SentryScreenshotIntegration / SentryViewHierarchyIntegration.
      static var screenshotCallback: ((String) -> Void)?
      static var viewHierarchyCallback: ((String) -> Void)?

      static func attachmentsDirectory(for reportIDHex: String) -> URL? {
          guard let base = basePath else { return nil }
          return URL(fileURLWithPath: base).appendingPathComponent(reportIDHex)
      }

      static func attachments(for reportIDHex: String) -> [Attachment] {
          guard let dir = attachmentsDirectory(for: reportIDHex) else { return [] }
          guard let files = try? FileManager.default.contentsOfDirectory(
              at: dir, includingPropertiesForKeys: nil
          ) else { return [] }

          return files.compactMap { url in
              let name = url.lastPathComponent
              switch url.pathExtension {
              case "png":
                  return Attachment(path: url.path, filename: name, contentType: "image/png")
              case "json":
                  let attachmentType: SentryAttachmentType = name == "view-hierarchy.json"
                      ? .viewHierarchy : .eventAttachment
                  return Attachment(
                      path: url.path,
                      filename: name,
                      contentType: "application/json",
                      attachmentType: attachmentType
                  )
              default:
                  return nil
              }
          }
      }

      static func cleanup(for reportIDHex: String) {
          guard let dir = attachmentsDirectory(for: reportIDHex) else { return }
          try? FileManager.default.removeItem(at: dir)
      }
  }
  ```

- [ ] **Step 2: Build to verify it compiles**

  ```bash
  make build-ios
  ```
  Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

  ```bash
  git add Sources/Swift/Integrations/KSCrash/SentryCrashAttachmentsStorage.swift
  git commit -m "ref: add SentryCrashAttachmentsStorage for crash-time attachment state"
  ```

---

## Task 2: Switch integrations to Swift closures

Replace the C callback registration in `SentryScreenshotIntegration` and `SentryViewHierarchyIntegration` with Swift closure storage in `SentryCrashAttachmentsStorage`. Update their tests, which currently assert on `sentrycrash_hasSaveScreenshotCallback()` / `sentrycrash_hasSaveViewHierarchyCallback()`, to assert on the Swift storage instead.

**Files:**

- Modify: `Sources/Swift/Integrations/Screenshot/SentryScreenshotIntegration.swift`
- Modify: `Sources/Swift/Integrations/ViewHierarchy/SentryViewHierarchyIntegration.swift`
- Modify: `Tests/SentryTests/Integrations/Screenshot/SentryScreenshotIntegrationTests.swift`
- Modify: `Tests/SentryTests/Integrations/ViewHierarchy/SentryViewHierarchyIntegrationTests.swift`

- [ ] **Step 1: Write failing tests for `SentryScreenshotIntegration`**

  In `SentryScreenshotIntegrationTests`, replace the three `sentrycrash_hasSaveScreenshotCallback()` assertions:

  ```swift
  func test_attachScreenshot_disabled() {
      SentrySDK.start {
          $0.removeAllIntegrations()
          $0.attachScreenshot = false
      }
      XCTAssertEqual(SentrySDKInternal.currentHub().getClient()?.attachmentProcessors.count, 0)
      XCTAssertNil(SentryCrashAttachmentsStorage.screenshotCallback)
  }

  func test_attachScreenshot_enabled() {
      SentrySDK.start {
          $0.removeAllIntegrations()
          $0.attachScreenshot = true
      }
      XCTAssertEqual(SentrySDKInternal.currentHub().getClient()?.attachmentProcessors.count, 1)
      XCTAssertNotNil(SentryCrashAttachmentsStorage.screenshotCallback)
  }

  func test_uninstall() {
      SentrySDK.start {
          $0.removeAllIntegrations()
          $0.attachScreenshot = true
      }
      SentrySDK.close()
      XCTAssertNil(SentrySDKInternal.currentHub().getClient()?.attachmentProcessors)
      XCTAssertNil(SentryCrashAttachmentsStorage.screenshotCallback)
  }
  ```

- [ ] **Step 2: Run tests to verify they fail**

  ```bash
  make test-ios ONLY_TESTING=SentryTests/SentryScreenshotIntegrationTests/test_attachScreenshot_disabled
  ```
  Expected: FAIL — `SentryCrashAttachmentsStorage.screenshotCallback` is always nil

- [ ] **Step 3: Update `SentryScreenshotIntegration`**

  Replace the `sentrycrash_setSaveScreenshots` call in `init` and `uninstall`:

  ```swift
  // In init, replace:
  //   globalScreenshotSource = screenshotSource
  //   sentrycrash_setSaveScreenshots { path in
  //       guard let path = path else { return }
  //       let reportPath = String(cString: path)
  //       globalScreenshotSource?.saveScreenShots(reportPath)
  //   }
  // With:
  globalScreenshotSource = screenshotSource
  SentryCrashAttachmentsStorage.screenshotCallback = { path in
      globalScreenshotSource?.saveScreenShots(path)
  }

  // In uninstall, replace:
  //   globalScreenshotSource = nil
  //   sentrycrash_setSaveScreenshots(nil)
  // With:
  globalScreenshotSource = nil
  SentryCrashAttachmentsStorage.screenshotCallback = nil
  ```

- [ ] **Step 4: Run screenshot tests to verify they pass**

  ```bash
  make test-ios ONLY_TESTING=SentryTests/SentryScreenshotIntegrationTests
  ```
  Expected: All PASS

- [ ] **Step 5: Write failing tests for `SentryViewHierarchyIntegration`**

  In `SentryViewHierarchyIntegrationTests`, replace `sentrycrash_hasSaveViewHierarchyCallback()` assertions with `SentryCrashAttachmentsStorage.viewHierarchyCallback != nil` / `== nil` checks — same pattern as Step 1 above.

- [ ] **Step 6: Run those tests to verify they fail**

  ```bash
  make test-ios ONLY_TESTING=SentryTests/SentryViewHierarchyIntegrationTests
  ```
  Expected: FAIL on the callback-presence assertions

- [ ] **Step 7: Update `SentryViewHierarchyIntegration`**

  Replace the `sentrycrash_setSaveViewHierarchy` call in `init` and `uninstall`:

  ```swift
  // In init, replace:
  //   sentrycrash_setSaveViewHierarchy { path in
  //       guard let path = path else { return }
  //       let reportPath = String(cString: path)
  //       let filePath = (reportPath as NSString).appendingPathComponent("view-hierarchy.json")
  //       SentryDependencyContainer.sharedInstance().viewHierarchyProvider?.saveViewHierarchy(filePath)
  //   }
  // With:
  SentryCrashAttachmentsStorage.viewHierarchyCallback = { dirPath in
      let filePath = (dirPath as NSString).appendingPathComponent("view-hierarchy.json")
      SentryDependencyContainer.sharedInstance().viewHierarchyProvider?.saveViewHierarchy(filePath)
  }

  // In uninstall, replace:
  //   sentrycrash_setSaveViewHierarchy(nil)
  // With:
  SentryCrashAttachmentsStorage.viewHierarchyCallback = nil
  ```

- [ ] **Step 8: Run view-hierarchy tests to verify they pass**

  ```bash
  make test-ios ONLY_TESTING=SentryTests/SentryViewHierarchyIntegrationTests
  ```
  Expected: All PASS

- [ ] **Step 9: Commit**

  ```bash
  git add Sources/Swift/Integrations/Screenshot/SentryScreenshotIntegration.swift \
          Sources/Swift/Integrations/ViewHierarchy/SentryViewHierarchyIntegration.swift \
          Tests/SentryTests/Integrations/Screenshot/SentryScreenshotIntegrationTests.swift \
          Tests/SentryTests/Integrations/ViewHierarchy/SentryViewHierarchyIntegrationTests.swift
  git commit -m "ref: replace C attachment callbacks with Swift closures in integrations"
  ```

---

## Task 3: Wire `didWriteReportCallback` in `KSCrashIntegration`

**Files:**

- Modify: `Sources/Swift/Integrations/KSCrash/KSCrashIntegration.swift`
- Modify: `Tests/SentryTests/Integrations/KSCrash/KSCrashIntegrationTests.swift`

- [ ] **Step 1: Write a failing test**

  Add to `KSCrashIntegrationTests` (and add `SentryCrashAttachmentsStorage.basePath = nil` to `tearDown`):

  ```swift
  func test_startCrashHandler_setsAttachmentsBasePath() throws {
      _ = try fixture.getSut()
      let expectedBase = (fixture.options.cacheDirectoryPath as NSString)
          .appendingPathComponent("Attachments")
      XCTAssertEqual(SentryCrashAttachmentsStorage.basePath, expectedBase)
  }
  ```

- [ ] **Step 2: Run test to verify it fails**

  ```bash
  make test-ios ONLY_TESTING=SentryTests/KSCrashIntegrationTests/test_startCrashHandler_setsAttachmentsBasePath
  ```
  Expected: FAIL — `basePath` is nil

- [ ] **Step 3: Add `basePath` assignment and `didWriteReportCallback` in `startCrashHandler`**

  In `startCrashHandler`, after `config.installPath = options.cacheDirectoryPath`, add:

  ```swift
  let attachmentsBasePath = (options.cacheDirectoryPath as NSString)
      .appendingPathComponent("Attachments")
  SentryCrashAttachmentsStorage.basePath = attachmentsBasePath

  config.didWriteReportCallback = { plan, reportID in
      // Double-fault: we're crashing inside the crash handler; do as little as possible.
      guard !plan.pointee.crashedDuringExceptionHandling else { return }

      // Best-effort — mirrors original SentryCrash which always ran these after writing
      // the report, even from signal context. App is already dying; acceptable to risk it.
      let reportIDHex = String(format: "%016llx", UInt64(bitPattern: reportID))
      let dirPath = (attachmentsBasePath as NSString).appendingPathComponent(reportIDHex)
      try? FileManager.default.createDirectory(atPath: dirPath, withIntermediateDirectories: true)

      SentryCrashAttachmentsStorage.screenshotCallback?(dirPath)
      SentryCrashAttachmentsStorage.viewHierarchyCallback?(dirPath)
  }
  ```

- [ ] **Step 4: Run test to verify it passes**

  ```bash
  make test-ios ONLY_TESTING=SentryTests/KSCrashIntegrationTests/test_startCrashHandler_setsAttachmentsBasePath
  ```
  Expected: PASS

- [ ] **Step 5: Run all integration tests**

  ```bash
  make test-ios ONLY_TESTING=SentryTests/KSCrashIntegrationTests
  ```
  Expected: All PASS

- [ ] **Step 6: Commit**

  ```bash
  git add Sources/Swift/Integrations/KSCrash/KSCrashIntegration.swift \
          Tests/SentryTests/Integrations/KSCrash/KSCrashIntegrationTests.swift
  git commit -m "ref: wire didWriteReportCallback to invoke Swift attachment closures"
  ```

---

## Task 4: Load saved attachments in `KSCrashReportSink`

**Files:**

- Modify: `Sources/Swift/Integrations/KSCrash/KSCrashReportSink.swift`
- Modify: `Tests/SentryTests/Integrations/KSCrash/KSCrashReportSinkTests.swift`

- [ ] **Step 1: Write a failing test**

  Add to `KSCrashReportSinkTests`:

  ```swift
  func test_filterReports_loadsAndAttachesSavedFiles() throws {
      // -- Arrange --
      let reportIDHex = "000000000000abcd"
      let tempBase = FileManager.default.temporaryDirectory
          .appendingPathComponent("SentryAttachmentTest-\(UUID().uuidString)")
      let attachDir = tempBase.appendingPathComponent(reportIDHex)
      try FileManager.default.createDirectory(at: attachDir, withIntermediateDirectories: true)
      defer { try? FileManager.default.removeItem(at: tempBase) }

      try Data([0x89, 0x50, 0x4E, 0x47])
          .write(to: attachDir.appendingPathComponent("screenshot.png"))
      try Data("{\"windows\":[]}".utf8)
          .write(to: attachDir.appendingPathComponent("view-hierarchy.json"))

      SentryCrashAttachmentsStorage.basePath = tempBase.path
      defer { SentryCrashAttachmentsStorage.basePath = nil }

      // Minimal crash report dictionary carrying the report ID.
      let report = CrashReportDictionary.report(withValue: [
          "report": ["id": reportIDHex]
      ])

      // Wire up the SDK so captureFatalEvent doesn't bail.
      let options = Options()
      options.dsn = TestConstants.dsnAsString(username: "KSCrashReportSinkTests")
      let client = TestClient(options: options)
      SentrySDKInternal.setCurrentHub(TestHub(client: client, andScope: nil))
      defer { SentrySDKInternal.setCurrentHub(nil) }

      let sink = KSCrashReportSink(inAppLogic: SentryInAppLogic(inAppIncludes: []))
      let done = expectation(description: "completion")

      // -- Act --
      sink.filterReports([report]) { _, _ in done.fulfill() }
      wait(for: [done], timeout: 2.0)

      // -- Assert --
      let attachmentNames = (client.capturedEnvelopes.first?.items ?? [])
          .filter { $0.header.type == "attachment" }
          .compactMap { $0.header.filename }
      XCTAssertTrue(attachmentNames.contains("screenshot.png"))
      XCTAssertTrue(attachmentNames.contains("view-hierarchy.json"))

      XCTAssertFalse(
          FileManager.default.fileExists(atPath: attachDir.path),
          "Attachments directory should be deleted after capture"
      )
  }
  ```

  > Note: `TestClient`, `TestHub`, `TestConstants`, and `SentrySDKInternal.setCurrentHub` follow patterns in `KSCrashIntegrationTests.swift`. If `setCurrentHub` isn't directly available, check how that test file binds the hub and replicate it.

- [ ] **Step 2: Run test to verify it fails**

  ```bash
  make test-ios ONLY_TESTING=SentryTests/KSCrashReportSinkTests/test_filterReports_loadsAndAttachesSavedFiles
  ```
  Expected: FAIL — no attachments loaded yet

- [ ] **Step 3: Extract report ID in `sendReports` and pass to `handleConvertedEvent`**

  In `sendReports`, extract the report ID from each `CrashReportDictionary` before converting:

  ```swift
  for report in reports {
      guard let dictReport = report as? CrashReportDictionary else {
          SentrySDKLog.warning("KSCrashReportSink: skipping non-dictionary report of type \(type(of: report))")
          continue
      }
      let reportIDHex = (dictReport.value["report"] as? [String: Any])?["id"] as? String
      let reportConverter = KSCrashReportConverter(report: dictReport, inAppLogic: inAppLogic)
      if SentrySDKInternal.currentHub().getClient() != nil {
          if let event = reportConverter.convertReportToEvent() {
              handleConvertedEvent(event, report: report, reportIDHex: reportIDHex, sentReports: &sentReports)
          }
      } else {
          SentrySDKLog.error(
              "Crash reports were found but no [SentrySDK.currentHub getClient] is set. " +
              "Cannot send crash reports to Sentry. This is probably a misconfiguration, " +
              "make sure you set the client with [SentrySDK.currentHub bindClient] before " +
              "calling startCrashHandlerWithError:."
          )
      }
  }
  ```

- [ ] **Step 4: Update `handleConvertedEvent` to load and attach saved files**

  Replace the existing `handleConvertedEvent`:

  ```swift
  private func handleConvertedEvent(
      _ event: Event,
      report: any CrashReport,
      reportIDHex: String?,
      sentReports: inout [any CrashReport]
  ) {
      sentReports.append(report)
      let scope = Scope(scope: SentrySDKInternal.currentHub().scope)

      if let reportIDHex {
          for attachment in SentryCrashAttachmentsStorage.attachments(for: reportIDHex) {
              scope.addAttachment(attachment)
          }
          SentryCrashAttachmentsStorage.cleanup(for: reportIDHex)
      }

      SentrySDKInternal.captureFatalEvent(event, with: scope)
  }
  ```

- [ ] **Step 5: Run test to verify it passes**

  ```bash
  make test-ios ONLY_TESTING=SentryTests/KSCrashReportSinkTests/test_filterReports_loadsAndAttachesSavedFiles
  ```
  Expected: PASS

- [ ] **Step 6: Run full KSCrash test suites**

  ```bash
  make test-ios ONLY_TESTING=SentryTests/KSCrashReportSinkTests
  make test-ios ONLY_TESTING=SentryTests/KSCrashIntegrationTests
  make test-ios ONLY_TESTING=SentryTests/SentryScreenshotIntegrationTests
  make test-ios ONLY_TESTING=SentryTests/SentryViewHierarchyIntegrationTests
  ```
  Expected: All PASS

- [ ] **Step 7: Commit**

  ```bash
  git add Sources/Swift/Integrations/KSCrash/KSCrashReportSink.swift \
          Tests/SentryTests/Integrations/KSCrash/KSCrashReportSinkTests.swift
  git commit -m "ref: load crash-time attachments in KSCrashReportSink"
  ```

---

## Self-Review

**Spec coverage:**

- Swift closure storage for screenshot and view-hierarchy callbacks — Task 1 ✓
- `SentryScreenshotIntegration` and `SentryViewHierarchyIntegration` register/clear Swift closures — Task 2 ✓
- `didWriteReportCallback` invokes Swift closures, no C bridge — Task 3 ✓
- Attachments loaded and added to crash event on next launch, cleaned up after — Task 4 ✓
- Best-effort always-on, guarded only on `crashedDuringExceptionHandling` — Task 3 ✓
- Zero new C/ObjC code — existing `SentryAttachmentCallback.c` stubs untouched ✓

**No-ops removed:** `sentrycrash_setSaveScreenshots` / `sentrycrash_setSaveViewHierarchy` calls are removed from both integrations. Their C stubs in `SentryAttachmentCallback.c` become fully dead and can be deleted in a follow-up.

**Placeholder scan:** No TBDs, all steps have concrete code.

**Type consistency:**

- `SentryCrashAttachmentsStorage.screenshotCallback` and `viewHierarchyCallback` are both `((String) -> Void)?` — matches usage in `KSCrashIntegration` (passes `String`) and in integrations (receives `String`).
- `SentryCrashAttachmentsStorage.attachments(for:)` returns `[Attachment]` — matches `scope.addAttachment(_ attachment: Attachment)`.
- `cleanup(for:)` is called before `captureFatalEvent` returns, so files exist when the envelope is built.
