@_spi(Private) import SentryTestUtils
#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif
import Foundation
import XCTest

#if os(iOS) || os(tvOS)

class SessionReplayRecoveryTests: XCTestCase {

    private var cacheDirectoryPath: String?

    override func tearDownWithError() throws {
        SentrySDKInternal.setCurrentHub(nil)
        if let cacheDirectoryPath, FileManager.default.fileExists(atPath: cacheDirectoryPath) {
            try FileManager.default.removeItem(atPath: cacheDirectoryPath)
        }
        try super.tearDownWithError()
    }

    func testResumePreviousSessionReplay_whenCalledOffProcessingQueue_shouldEncodeOnProcessingQueue() throws {
        // -- Arrange --
        let options = Options()
        options.dsn = "https://user@test.com/test"
        options.cacheDirectoryPath = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .path
        cacheDirectoryPath = options.cacheDirectoryPath

        let fileDispatchQueue = TestSentryDispatchQueueWrapper()
        let fileManager = try SentryFileManager(
            options: options,
            dateProvider: TestCurrentDateProvider(),
            dispatchQueueWrapper: fileDispatchQueue
        )
        let replayFileManager = SessionReplayFileManager(
            fileManager: fileManager,
            sharedDispatchQueue: fileDispatchQueue
        )

        let replayId = SentryId()
        let replayDirectory = try XCTUnwrap(replayFileManager.replayDirectory())
        try FileManager.default.createDirectory(at: replayDirectory, withIntermediateDirectories: true)

        let sessionFolderName = UUID().uuidString
        let info: [String: Any] = [
            "replayId": replayId.sentryIdString,
            "path": sessionFolderName,
            "errorSampleRate": 0,
            "replayType": SentryReplayType.session.toString()
        ]
        let infoData = try XCTUnwrap(SentrySerializationSwift.data(withJSONObject: info))
        try infoData.write(to: replayDirectory.appendingPathComponent("replay.last"))

        let sessionFolder = replayDirectory.appendingPathComponent(sessionFolderName)
        try FileManager.default.createDirectory(at: sessionFolder, withIntermediateDirectories: true)
        for timestamp in 5...9 {
            let imageData = try XCTUnwrap(UIImage.add.jpegData(compressionQuality: 1))
            try imageData.write(to: sessionFolder.appendingPathComponent("\(timestamp).png"))
        }

        let processingQueue = TestSentryDispatchQueueWrapper()
        processingQueue.dispatchAsyncExecutesBlock = false
        let assetWorkerQueue = TestSentryDispatchQueueWrapper()
        let idleGate = SentryReplayRecoveryIdleGate()

        let sut = SessionReplayRecovery(
            replayOptions: SentryReplayOptions(sessionSampleRate: 0, onErrorSampleRate: 0),
            random: TestRandom(value: 0),
            replayProcessingQueue: processingQueue,
            replayAssetWorkerQueue: assetWorkerQueue,
            replayFileManager: replayFileManager,
            breadcrumbConverter: SentrySRDefaultBreadcrumbConverter(),
            idleGate: idleGate
        )

        let hub = TestHub(client: nil, andScope: Scope())
        SentrySDKInternal.setCurrentHub(hub)
        let replayCapture = expectation(description: "Replay capture")
        hub.onReplayCapture = {
            replayCapture.fulfill()
        }

        let crash = Event(error: NSError(domain: "Error", code: 1))
        crash.context = [:]
        crash.isFatalEvent = true

        // -- Act --
        sut.resumePreviousSessionReplay(crash)

        // -- Assert --
        XCTAssertEqual(
            (crash.context?["replay"] as? [String: Any])?["replay_id"] as? String,
            replayId.sentryIdString
        )
        XCTAssertEqual(hub.capturedReplayRecordingVideo.count, 0)
        XCTAssertEqual(processingQueue.dispatchAsyncCalled, 1)
        XCTAssertFalse(idleGate.waitForIdle(timeout: 0))

        processingQueue.invokeLastDispatchAsync()
        wait(for: [replayCapture], timeout: 10)
        XCTAssertEqual(hub.capturedReplayRecordingVideo.count, 1)
        XCTAssertTrue(idleGate.waitForIdle(timeout: 0))
    }

    func testResumePreviousSessionReplay_whenMultipleFatalEvents_shouldStampReplayIdOnFirstOnly() throws {
        // -- Arrange --
        let options = Options()
        options.dsn = "https://user@test.com/test"
        options.cacheDirectoryPath = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .path
        cacheDirectoryPath = options.cacheDirectoryPath

        let fileDispatchQueue = TestSentryDispatchQueueWrapper()
        let fileManager = try SentryFileManager(
            options: options,
            dateProvider: TestCurrentDateProvider(),
            dispatchQueueWrapper: fileDispatchQueue
        )
        let replayFileManager = SessionReplayFileManager(
            fileManager: fileManager,
            sharedDispatchQueue: fileDispatchQueue
        )

        let replayId = SentryId()
        let replayDirectory = try XCTUnwrap(replayFileManager.replayDirectory())
        try FileManager.default.createDirectory(at: replayDirectory, withIntermediateDirectories: true)

        let sessionFolderName = UUID().uuidString
        let info: [String: Any] = [
            "replayId": replayId.sentryIdString,
            "path": sessionFolderName,
            "errorSampleRate": 0,
            "replayType": SentryReplayType.session.toString()
        ]
        let infoData = try XCTUnwrap(SentrySerializationSwift.data(withJSONObject: info))
        let lastReplayPath = replayDirectory.appendingPathComponent("replay.last")
        try infoData.write(to: lastReplayPath)

        let sessionFolder = replayDirectory.appendingPathComponent(sessionFolderName)
        try FileManager.default.createDirectory(at: sessionFolder, withIntermediateDirectories: true)
        for timestamp in 5...9 {
            let imageData = try XCTUnwrap(UIImage.add.jpegData(compressionQuality: 1))
            try imageData.write(to: sessionFolder.appendingPathComponent("\(timestamp).png"))
        }

        let processingQueue = TestSentryDispatchQueueWrapper()
        processingQueue.dispatchAsyncExecutesBlock = false
        let assetWorkerQueue = TestSentryDispatchQueueWrapper()
        let idleGate = SentryReplayRecoveryIdleGate()

        let sut = SessionReplayRecovery(
            replayOptions: SentryReplayOptions(sessionSampleRate: 0, onErrorSampleRate: 0),
            random: TestRandom(value: 0),
            replayProcessingQueue: processingQueue,
            replayAssetWorkerQueue: assetWorkerQueue,
            replayFileManager: replayFileManager,
            breadcrumbConverter: SentrySRDefaultBreadcrumbConverter(),
            idleGate: idleGate
        )

        let hub = TestHub(client: nil, andScope: Scope())
        SentrySDKInternal.setCurrentHub(hub)
        let replayCapture = expectation(description: "Replay capture")
        hub.onReplayCapture = {
            replayCapture.fulfill()
        }

        let firstCrash = Event(error: NSError(domain: "Error", code: 1))
        firstCrash.context = [:]
        firstCrash.isFatalEvent = true

        let secondCrash = Event(error: NSError(domain: "Error", code: 2))
        secondCrash.context = [:]
        secondCrash.isFatalEvent = true

        // -- Act --
        sut.resumePreviousSessionReplay(firstCrash)
        sut.resumePreviousSessionReplay(secondCrash)

        // -- Assert --
        XCTAssertEqual(
            (firstCrash.context?["replay"] as? [String: Any])?["replay_id"] as? String,
            replayId.sentryIdString
        )
        XCTAssertNil(secondCrash.context?["replay"])
        XCTAssertTrue(FileManager.default.fileExists(atPath: lastReplayPath.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: sessionFolder.path))
        XCTAssertEqual(processingQueue.dispatchAsyncCalled, 1)
        XCTAssertFalse(idleGate.waitForIdle(timeout: 0))

        processingQueue.invokeLastDispatchAsync()
        wait(for: [replayCapture], timeout: 10)
        XCTAssertEqual(hub.capturedReplayRecordingVideo.count, 1)
        XCTAssertTrue(idleGate.waitForIdle(timeout: 0))
        XCTAssertFalse(FileManager.default.fileExists(atPath: lastReplayPath.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: sessionFolder.path))
    }
}

#endif
