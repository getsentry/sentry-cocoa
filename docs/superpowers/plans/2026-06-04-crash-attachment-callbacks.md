# Crash-Time Screenshot & View Hierarchy Attachments

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire crash-time screenshot and view-hierarchy saving through KSCrash's `didWriteReportCallback`, and load those saved files as attachments on the next launch when the crash event is sent.

**Architecture:** `KSCrashIntegration` sets `config.didWriteReportCallback` to invoke the registered attachment callbacks (stored in `SentryAttachmentCallback.c`) after each crash report is written, saving files to `<installPath>/Attachments/<reportIDHex>/`. This is a **best-effort, always-on** attempt — mirroring the original SentryCrash behaviour which ran the callbacks unconditionally after writing the report, even in signal-handler context ("since the app is already in a crash state we don't mind if this approach crashes"). On the next launch, `KSCrashReportSink` reads the report ID out of each crash report dictionary, loads any files in the corresponding directory, attaches them to the copied scope, and cleans up after capture.

**Tech Stack:** Swift, Objective-C/C, XCTest, KSCrash v2 (`KSCrashConfiguration.didWriteReportCallback`, `KSCrash_ExceptionHandlingPlan`)

---

## Background

`SentryScreenshotIntegration` and `SentryViewHierarchyIntegration` each register a `SaveAttachmentCallback` via `sentrycrash_setSaveScreenshots` / `sentrycrash_setSaveViewHierarchy`. Those callbacks are stored in globals in `SentryAttachmentCallback.c`, but nothing ever calls them. The upstream KSCrash v2 `didWriteReportCallback` is the correct replacement hook.

The callback only receives `(plan, reportID: int64_t)`, not a path. We derive the path ourselves using the `installPath` captured at install time, stored in a module-level global `SentryCrashAttachmentsStorage.basePath`.

The original SentryCrash always attempted to save attachments after writing the report, even in signal-handler context, with an explicit comment: "since the app is already in a crash state we don't mind if this approach crashes." We preserve that best-effort behaviour — the only case we skip is `crashedDuringExceptionHandling`, where a second crash during exception handling means we should do as little as possible.

---

## File Map

| Action | Path |
|--------|------|
| Modify | `Sources/Sentry/SentryAttachmentCallback.c` |
| Modify | `Sources/Sentry/include/SentryAttachmentCallback.h` |
| Modify | `Sources/Sentry/include/SentryCrashC.h` |
| Create | `Sources/Swift/Integrations/KSCrash/SentryCrashAttachmentsStorage.swift` |
| Modify | `Sources/Swift/Integrations/KSCrash/KSCrashIntegration.swift` |
| Modify | `Sources/Swift/Integrations/KSCrash/KSCrashReportSink.swift` |
| Modify | `Tests/SentryTests/Integrations/KSCrash/KSCrashReportSinkTests.swift` |
| Modify | `Tests/SentryTests/Integrations/KSCrash/KSCrashIntegrationTests.swift` |
| Modify | `Tests/SentryTests/Integrations/Screenshot/SentryScreenshotIntegrationTests.swift` |

---

## Task 1: Add `sentrycrash_invokeAttachmentCallbacks` C function

**Files:**
- Modify: `Sources/Sentry/include/SentryAttachmentCallback.h`
- Modify: `Sources/Sentry/include/SentryCrashC.h`
- Modify: `Sources/Sentry/SentryAttachmentCallback.c`
- Test: `Tests/SentryTests/Integrations/Screenshot/SentryScreenshotIntegrationTests.swift`

- [ ] **Step 1: Write failing tests**

  Add to `SentryScreenshotIntegrationTests` (inside the `#if os(iOS) || os(tvOS)` guard):

  ```swift
  func test_invokeAttachmentCallbacks_callsBothCallbacks() {
      var screenshotPath: String?
      var viewHierarchyPath: String?

      sentrycrash_setSaveScreenshots { path in
          screenshotPath = path.map { String(cString: $0) }
      }
      sentrycrash_setSaveViewHierarchy { path in
          viewHierarchyPath = path.map { String(cString: $0) }
      }
      defer {
          sentrycrash_setSaveScreenshots(nil)
          sentrycrash_setSaveViewHierarchy(nil)
      }

      sentrycrash_invokeAttachmentCallbacks("/tmp/test-dir")

      XCTAssertEqual(screenshotPath, "/tmp/test-dir")
      XCTAssertEqual(viewHierarchyPath, "/tmp/test-dir")
  }

  func test_invokeAttachmentCallbacks_nilCallbacks_doesNotCrash() {
      sentrycrash_setSaveScreenshots(nil)
      sentrycrash_setSaveViewHierarchy(nil)
      // Should not crash
      sentrycrash_invokeAttachmentCallbacks("/tmp/test-dir")
  }
  ```

- [ ] **Step 2: Run tests to verify they fail**

  ```bash
  make test-ios ONLY_TESTING=SentryTests/SentryScreenshotIntegrationTests/test_invokeAttachmentCallbacks_callsBothCallbacks
  ```
  Expected: FAIL — `sentrycrash_invokeAttachmentCallbacks` undeclared

- [ ] **Step 3: Declare in `SentryAttachmentCallback.h`**

  Add after the existing `sentrycrash_hasSaveViewHierarchyCallback` declaration:

  ```c
  /** Invoke both screenshot and view-hierarchy callbacks (if registered) with the given directory.
   *
   * @param directoryPath The directory where attachments should be saved.
   */
  void sentrycrash_invokeAttachmentCallbacks(const char *directoryPath);
  ```

- [ ] **Step 4: Declare in `SentryCrashC.h`**

  Add after the existing `sentrycrash_hasSaveViewHierarchyCallback` declaration (around line 234):

  ```c
  /** Invoke both screenshot and view-hierarchy callbacks (if registered) with the given directory.
   *
   * @param directoryPath The directory where attachments should be saved.
   */
  void sentrycrash_invokeAttachmentCallbacks(const char *directoryPath);
  ```

- [ ] **Step 5: Implement in `SentryAttachmentCallback.c`**

  Add after `sentrycrash_hasSaveViewHierarchyCallback`:

  ```c
  void
  sentrycrash_invokeAttachmentCallbacks(const char *directoryPath)
  {
      if (g_saveScreenshots != NULL) {
          g_saveScreenshots(directoryPath);
      }
      if (g_saveViewHierarchy != NULL) {
          g_saveViewHierarchy(directoryPath);
      }
  }
  ```

- [ ] **Step 6: Run tests to verify they pass**

  ```bash
  make test-ios ONLY_TESTING=SentryTests/SentryScreenshotIntegrationTests/test_invokeAttachmentCallbacks_callsBothCallbacks
  make test-ios ONLY_TESTING=SentryTests/SentryScreenshotIntegrationTests/test_invokeAttachmentCallbacks_nilCallbacks_doesNotCrash
  ```
  Expected: PASS

- [ ] **Step 7: Commit**

  ```bash
  git add Sources/Sentry/SentryAttachmentCallback.c \
          Sources/Sentry/include/SentryAttachmentCallback.h \
          Sources/Sentry/include/SentryCrashC.h \
          Tests/SentryTests/Integrations/Screenshot/SentryScreenshotIntegrationTests.swift
  git commit -m "ref: add sentrycrash_invokeAttachmentCallbacks C helper"
  ```

---

## Task 2: Add `SentryCrashAttachmentsStorage` helper

**Files:**
- Create: `Sources/Swift/Integrations/KSCrash/SentryCrashAttachmentsStorage.swift`

No dedicated test file needed — this is tested implicitly through the `KSCrashReportSink` tests in Task 4.

- [ ] **Step 1: Create the file**

  ```swift
  // Sources/Swift/Integrations/KSCrash/SentryCrashAttachmentsStorage.swift
  @_implementationOnly import _SentryPrivate
  import Foundation

  enum SentryCrashAttachmentsStorage {
      static var basePath: String?

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
              let contentType: String
              let attachmentType: SentryAttachmentType

              switch url.pathExtension {
              case "png":
                  contentType = "image/png"
                  attachmentType = .eventAttachment
              case "json":
                  contentType = "application/json"
                  attachmentType = name == "view-hierarchy.json" ? .viewHierarchy : .eventAttachment
              default:
                  return nil
              }
              return Attachment(path: url.path, filename: name, contentType: contentType, attachmentType: attachmentType)
          }
      }

      static func cleanup(for reportIDHex: String) {
          guard let dir = attachmentsDirectory(for: reportIDHex) else { return }
          try? FileManager.default.removeItem(at: dir)
      }
  }
  ```

- [ ] **Step 2: Build to confirm it compiles**

  ```bash
  make build-ios
  ```
  Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

  ```bash
  git add Sources/Swift/Integrations/KSCrash/SentryCrashAttachmentsStorage.swift
  git commit -m "ref: add SentryCrashAttachmentsStorage for crash-time attachment paths"
  ```

---

## Task 3: Wire `didWriteReportCallback` in `KSCrashIntegration`

**Files:**
- Modify: `Sources/Swift/Integrations/KSCrash/KSCrashIntegration.swift`
- Test: `Tests/SentryTests/Integrations/KSCrash/KSCrashIntegrationTests.swift`

- [ ] **Step 1: Write a failing test**

  Add to `KSCrashIntegrationTests`:

  ```swift
  func test_startCrashHandler_setsAttachmentsBasePath() throws {
      _ = try fixture.getSut()
      // The basePath should be set to <cacheDirectoryPath>/Attachments
      let expectedBase = (fixture.options.cacheDirectoryPath as NSString)
          .appendingPathComponent("Attachments")
      XCTAssertEqual(SentryCrashAttachmentsStorage.basePath, expectedBase)
  }
  ```

  Also add a `tearDown` entry to reset `SentryCrashAttachmentsStorage.basePath = nil` in the test class's `tearDown`.

- [ ] **Step 2: Run test to verify it fails**

  ```bash
  make test-ios ONLY_TESTING=SentryTests/KSCrashIntegrationTests/test_startCrashHandler_setsAttachmentsBasePath
  ```
  Expected: FAIL — `SentryCrashAttachmentsStorage.basePath` is nil

- [ ] **Step 3: Set `basePath` and add `didWriteReportCallback` in `KSCrashIntegration.startCrashHandler`**

  In `startCrashHandler`, after `let config = KSCrashConfiguration()` and `config.installPath = options.cacheDirectoryPath`, add:

  ```swift
  // Store the attachments base path so KSCrashReportSink can find them on next launch.
  let attachmentsBasePath = (options.cacheDirectoryPath as NSString)
      .appendingPathComponent("Attachments")
  SentryCrashAttachmentsStorage.basePath = attachmentsBasePath

  config.didWriteReportCallback = { plan, reportID in
      // Skip if we crashed while handling another exception — we're already in
      // an unstable state and should do as little as possible.
      guard !plan.pointee.crashedDuringExceptionHandling else { return }

      // Best-effort: mirrors original SentryCrash behaviour which always ran these
      // callbacks after writing the report, even from signal context ("since the app
      // is already in a crash state we don't mind if this approach crashes").
      let reportIDHex = String(format: "%016llx", UInt64(bitPattern: reportID))
      let dirPath = (attachmentsBasePath as NSString).appendingPathComponent(reportIDHex)

      try? FileManager.default.createDirectory(
          atPath: dirPath, withIntermediateDirectories: true
      )
      sentrycrash_invokeAttachmentCallbacks(dirPath)
  }
  ```

- [ ] **Step 4: Run test to verify it passes**

  ```bash
  make test-ios ONLY_TESTING=SentryTests/KSCrashIntegrationTests/test_startCrashHandler_setsAttachmentsBasePath
  ```
  Expected: PASS

- [ ] **Step 5: Run existing integration tests to check for regressions**

  ```bash
  make test-ios ONLY_TESTING=SentryTests/KSCrashIntegrationTests
  ```
  Expected: All PASS

- [ ] **Step 6: Commit**

  ```bash
  git add Sources/Swift/Integrations/KSCrash/KSCrashIntegration.swift \
          Tests/SentryTests/Integrations/KSCrash/KSCrashIntegrationTests.swift
  git commit -m "ref: wire didWriteReportCallback to save crash-time attachments"
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
      // Create a temp attachments directory as if didWriteReportCallback had run.
      let reportIDHex = "000000000000abcd"
      let tempBase = FileManager.default.temporaryDirectory
          .appendingPathComponent("SentryAttachmentTest-\(UUID().uuidString)")
      let attachDir = tempBase.appendingPathComponent(reportIDHex)
      try FileManager.default.createDirectory(at: attachDir, withIntermediateDirectories: true)

      let screenshotData = Data([0x89, 0x50, 0x4E, 0x47]) // PNG magic bytes
      try screenshotData.write(to: attachDir.appendingPathComponent("screenshot.png"))
      let jsonData = Data("{\"windows\":[]}".utf8)
      try jsonData.write(to: attachDir.appendingPathComponent("view-hierarchy.json"))

      SentryCrashAttachmentsStorage.basePath = tempBase.path
      defer {
          SentryCrashAttachmentsStorage.basePath = nil
          try? FileManager.default.removeItem(at: tempBase)
      }

      // Build a minimal crash report dictionary that contains the report ID.
      let reportDict: [String: Any] = [
          "report": ["id": reportIDHex]
      ]
      let report = CrashReportDictionary.report(withValue: reportDict)

      // Wire up a real SDK client so captureFatalEvent doesn't bail early.
      let options = Options()
      options.dsn = TestConstants.dsnAsString(username: "KSCrashReportSinkTests")
      let client = TestClient(options: options)
      SentrySDKInternal.setCurrentHub(TestHub(client: client, andScope: nil))
      defer { SentrySDKInternal.setCurrentHub(nil) }

      let logic = SentryInAppLogic(inAppIncludes: [])
      let sink = KSCrashReportSink(inAppLogic: logic)
      let expectation = expectation(description: "completion")

      // -- Act --
      sink.filterReports([report]) { _, _ in expectation.fulfill() }
      wait(for: [expectation], timeout: 2.0)

      // -- Assert --
      let capturedEvent = client.capturedEvents.first
      XCTAssertNotNil(capturedEvent, "Expected a fatal event to be captured")

      let attachmentNames = (client.capturedEnvelopes.first?.items ?? [])
          .filter { $0.header.type == "attachment" }
          .compactMap { $0.header.filename }
      XCTAssertTrue(attachmentNames.contains("screenshot.png"), "Expected screenshot.png attachment")
      XCTAssertTrue(attachmentNames.contains("view-hierarchy.json"), "Expected view-hierarchy.json attachment")

      // -- Cleanup check --
      XCTAssertFalse(
          FileManager.default.fileExists(atPath: attachDir.path),
          "Attachments directory should be deleted after capture"
      )
  }
  ```

  > Note: `TestClient`, `TestHub`, `TestConstants`, and `SentrySDKInternal.setCurrentHub` follow the patterns already used in `KSCrashIntegrationTests.swift`. If `setCurrentHub` isn't public, check how `KSCrashIntegrationTests` sets up the global hub and replicate that pattern.

- [ ] **Step 2: Run test to verify it fails**

  ```bash
  make test-ios ONLY_TESTING=SentryTests/KSCrashReportSinkTests/test_filterReports_loadsAndAttachesSavedFiles
  ```
  Expected: FAIL — no attachments are loaded yet

- [ ] **Step 3: Extract report ID from the crash report in `KSCrashReportSink.sendReports`**

  In `sendReports`, change the `for report in reports` loop to extract the report ID before calling `handleConvertedEvent`:

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

- [ ] **Step 4: Update `handleConvertedEvent` signature and body**

  Replace the existing `handleConvertedEvent` method:

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
          let savedAttachments = SentryCrashAttachmentsStorage.attachments(for: reportIDHex)
          for attachment in savedAttachments {
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

- [ ] **Step 6: Run all KSCrash sink and integration tests**

  ```bash
  make test-ios ONLY_TESTING=SentryTests/KSCrashReportSinkTests
  make test-ios ONLY_TESTING=SentryTests/KSCrashIntegrationTests
  ```
  Expected: All PASS

- [ ] **Step 7: Run screenshot integration tests**

  ```bash
  make test-ios ONLY_TESTING=SentryTests/SentryScreenshotIntegrationTests
  make test-ios ONLY_TESTING=SentryTests/SentryViewHierarchyIntegrationTests
  ```
  Expected: All PASS

- [ ] **Step 8: Commit**

  ```bash
  git add Sources/Swift/Integrations/KSCrash/KSCrashReportSink.swift \
          Tests/SentryTests/Integrations/KSCrash/KSCrashReportSinkTests.swift
  git commit -m "ref: load crash-time attachments in KSCrashReportSink"
  ```

---

## Self-Review

**Spec coverage:**
- `sentrycrash_invokeAttachmentCallbacks` declared and implemented — Task 1 ✓
- Storage helper for path management — Task 2 ✓
- `didWriteReportCallback` wired to save screenshots and view hierarchy at crash time — Task 3 ✓
- Attachments loaded and added to crash event on next launch, then cleaned up — Task 4 ✓
- Best-effort always-on, guarded only on `crashedDuringExceptionHandling` — Task 3 ✓

**No-ops removed:** The stubs in `SentryAttachmentCallback.c` now actually call through; the `sentrycrash_setSaveScreenshots` / `sentrycrash_setSaveViewHierarchy` integration code in `SentryScreenshotIntegration` and `SentryViewHierarchyIntegration` is unchanged and correct.

**Placeholder scan:** No TBDs, no vague steps, all code blocks present.

**Type consistency:**
- `SentryCrashAttachmentsStorage.attachments(for:)` returns `[Attachment]` — consistent with `scope.addAttachment` which takes `Attachment`.
- `SentryCrashAttachmentsStorage.cleanup(for:)` called after `captureFatalEvent` (all attachments already enrolled in envelope before cleanup).
- `sentrycrash_invokeAttachmentCallbacks` takes `const char *` — consistent with `SaveAttachmentCallback` typedef.
