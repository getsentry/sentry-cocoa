// swiftlint:disable file_length
@testable import Sentry
import SentryTestUtils
import XCTest

class SentryFileIOTrackerSwiftHelpersTests: XCTestCase {
    private var hub: SentryHub!
    private var tracker: SentryFileIOTracker!
    private var mockedDateProvider: TestCurrentDateProvider!

    private let testData = Data([0x00, 0x01, 0x02, 0x03])
    private let testUrl = URL(fileURLWithPath: "/path/to/file")
    private let testPath = "/path/to/file"
    private let testReadingOptions: Data.ReadingOptions = [.alwaysMapped]
    private let testWritingOptions: Data.WritingOptions = [.atomic]
    private let createFileAttributes: [FileAttributeKey: Any] = [.modificationDate: Date(timeIntervalSince1970: 1_000_000)]
    private let testOrigin = "custom.origin"
    private let nonFileUrl = URL(string: "https://sentry.io/test.txt")!
    private let destUrl = URL(fileURLWithPath: "/path/to/dest")
    private let destPath = "/path/to/dest"
    private let testError = NSError(domain: "Test", code: 1, userInfo: nil)

    override func setUp() {
        mockedDateProvider = TestCurrentDateProvider()
        SentryDependencyContainer.sharedInstance().dateProvider = mockedDateProvider

        hub = SentryHub(client: nil, andScope: nil)
        SentrySDK.setCurrentHub(hub)

        tracker = SentryFileIOTracker(
            threadInspector: TestThreadInspector(options: .noIntegrations()),
            processInfoWrapper: TestSentryNSProcessInfoWrapper()
        )
    }

    // MARK: - SentryFileIOTracker.measureReadingData(from:options:origin:)

    func testMeasureReadingData_whenIsEnabled_shouldCreateSpanWithOrderedTimestamps() throws {
        // -- Arrange --
        tracker.enable()

        // -- Act --
        mockedDateProvider.setDate(date: Date(timeIntervalSince1970: 4_000_000))
        let transaction = hub.startTransaction(name: "Transaction", operation: "Test", bindToScope: true)

        // Advance the time to make sure the child span has a different start time than the parent span
        mockedDateProvider.setDate(date: Date(timeIntervalSince1970: 4_100_000))
        let _ = tracker.measureReadingData(from: testUrl, options: testReadingOptions, origin: testOrigin) { _, _ in
            // Advance the time to make sure the child span has a different start and end time
            mockedDateProvider.setDate(date: Date(timeIntervalSince1970: 4_200_000))
            return testData
        }

        // Advance the time to make sure the parent span has a different end time than the child span
        mockedDateProvider.setDate(date: Date(timeIntervalSince1970: 4_300_000))
        transaction.finish()

        // -- Assert --
        let parentSpan = try XCTUnwrap(transaction as? SentryTracer)
        XCTAssertEqual(parentSpan.children.count, 1)
        let span = try XCTUnwrap(parentSpan.children.first)

        XCTAssertEqual(span.status, SentrySpanStatus.ok)
        XCTAssertEqual(span.origin, testOrigin)
        XCTAssertEqual(span.operation, SentrySpanOperationFileRead)
        XCTAssertEqual(span.data["file.path"] as? String, testUrl.path)
        XCTAssertEqual(span.data["file.size"] as? Int, testData.count)

        XCTAssertEqual(parentSpan.startTimestamp, Date(timeIntervalSince1970: 4_000_000))
        XCTAssertEqual(span.startTimestamp, Date(timeIntervalSince1970: 4_100_000))
        XCTAssertEqual(span.timestamp, Date(timeIntervalSince1970: 4_200_000))
        XCTAssertEqual(parentSpan.timestamp, Date(timeIntervalSince1970: 4_300_000))
    }

    func testMeasureReadingData_whenIsEnabled_shouldCallBlockWithParams() throws {
        // -- Arrange --
        tracker.enable()

        // -- Act --
        var callUrl: URL?
        var callOptions: Data.ReadingOptions?
        let result = tracker.measureReadingData(from: testUrl, options: testReadingOptions, origin: testOrigin) { url, options in
            callUrl = url
            callOptions = options
            return testData
        }

        // -- Assert --
        XCTAssertEqual(callUrl, testUrl)
        XCTAssertEqual(callOptions, testReadingOptions)
        XCTAssertEqual(result, testData)
    }

    func testMeasureReadingData_whenIsNotEnabled_shouldNotCreateSpan() throws {
        // -- Arrange --
        tracker.disable()

        // -- Act --
        let transaction = hub.startTransaction(name: "Transaction", operation: "Test", bindToScope: true)
        var isCalled = false
        let result = tracker.measureReadingData(from: testUrl, options: testReadingOptions, origin: testOrigin) { _, _ in
            isCalled = true
            return testData
        }
        transaction.finish()

        // -- Assert --
        XCTAssertEqual(result, testData)
        XCTAssertTrue(isCalled)

        let parentSpan = try XCTUnwrap(transaction as? SentryTracer)
        XCTAssertEqual(parentSpan.children.count, 0)
    }

    func testMeasureReadingData_whenIsNotEnabled_shouldCallBlockWithParams() throws {
        // -- Arrange --
        tracker.disable()

        // -- Act --
        var callUrl: URL?
        var callOptions: Data.ReadingOptions?
        let result = tracker.measureReadingData(from: testUrl, options: testReadingOptions, origin: testOrigin) { url, options in
            callUrl = url
            callOptions = options
            return testData
        }

        // -- Assert --
        XCTAssertEqual(callUrl, testUrl)
        XCTAssertEqual(callOptions, testReadingOptions)
        XCTAssertEqual(result, testData)
    }

    func testMeasureReadingData_whenNonFileURL_shouldNotCreateSpan() throws {
        // -- Arrange --
        tracker.enable()

        // -- Act --
        let transaction = hub.startTransaction(name: "Transaction", operation: "Test", bindToScope: true)
        var isCalled = false
        let result = tracker.measureReadingData(from: nonFileUrl, options: testReadingOptions, origin: testOrigin) { _, _ in
            isCalled = true
            return testData
        }
        transaction.finish()

        // -- Assert --
        XCTAssertEqual(result, testData)
        XCTAssertTrue(isCalled)

        let parentSpan = try XCTUnwrap(transaction as? SentryTracer)
        XCTAssertEqual(parentSpan.children.count, 0)
    }

    func testMeasureReadingData_whenNonFileURL_shouldCallBlockWithParams() throws {
        // -- Arrange --
        tracker.enable()

        // -- Act --
        var callUrl: URL?
        var callOptions: Data.ReadingOptions?
        let result = tracker.measureReadingData(from: nonFileUrl, options: testReadingOptions, origin: testOrigin) { url, options in
            callUrl = url
            callOptions = options
            return testData
        }

        // -- Assert --
        XCTAssertEqual(callUrl, nonFileUrl)
        XCTAssertEqual(callOptions, testReadingOptions)
        XCTAssertEqual(result, testData)
    }

    func testMeasureReadingData_whenThrowsError_shouldFinishSpanWithInternalError() throws {
        // -- Arrange --
        tracker.enable()

        // -- Act --
        let transaction = hub.startTransaction(name: "Transaction", operation: "Test", bindToScope: true)
        XCTAssertThrowsError(try tracker.measureReadingData(from: testUrl, options: testReadingOptions, origin: testOrigin) { _, _ in
            throw testError
        })
        transaction.finish()

        // -- Assert --
        let parentSpan = try XCTUnwrap(transaction as? SentryTracer)
        XCTAssertEqual(parentSpan.children.count, 1)
        let span = try XCTUnwrap(parentSpan.children.first)

        XCTAssertEqual(span.status, SentrySpanStatus.internalError)
    }

    func testMeasureReadingData_whenThrowsError_shouldRethrow() throws {
        // -- Arrange --
        tracker.enable()

        // -- Act --
        var thrownError: (any Error)?
        XCTAssertThrowsError(try tracker.measureReadingData(from: testUrl, options: testReadingOptions, origin: testOrigin) { _, _ in
            throw testError
        }, "", { (error: any Error) in
            thrownError = error
        })

        // -- Assert --
        XCTAssertEqual(thrownError as? NSError, testError)
    }

    // MARK: - SentryFileIOTracker.measureReadingData(to:options:origin:)

    func testMeasureWritingData_whenIsEnabled_shouldCreateSpanWithOrderedTimestamps() throws {
        // -- Arrange --
        tracker.enable()

        // -- Act --
        mockedDateProvider.setDate(date: Date(timeIntervalSince1970: 4_000_000))
        let transaction = hub.startTransaction(name: "Transaction", operation: "Test", bindToScope: true)

        // Advance the time to make sure the child span has a different start time than the parent span
        mockedDateProvider.setDate(date: Date(timeIntervalSince1970: 4_100_000))
        tracker.measureWritingData(testData, to: testUrl, options: testWritingOptions, origin: testOrigin) { _, _, _ in
            // Advance the time to make sure the child span has a different start and end time
            mockedDateProvider.setDate(date: Date(timeIntervalSince1970: 4_200_000))
        }

        // Advance the time to make sure the parent span has a different end time than the child span
        mockedDateProvider.setDate(date: Date(timeIntervalSince1970: 4_300_000))
        transaction.finish()

        // -- Assert --
        let parentSpan = try XCTUnwrap(transaction as? SentryTracer)
        XCTAssertEqual(parentSpan.children.count, 1)
        let span = try XCTUnwrap(parentSpan.children.first)

        XCTAssertEqual(span.status, SentrySpanStatus.ok)
        XCTAssertEqual(span.origin, testOrigin)
        XCTAssertEqual(span.operation, SentrySpanOperationFileWrite)
        XCTAssertEqual(span.data["file.path"] as? String, testUrl.path)
        XCTAssertEqual(span.data["file.size"] as? Int, testData.count)

        XCTAssertEqual(parentSpan.startTimestamp, Date(timeIntervalSince1970: 4_000_000))
        XCTAssertEqual(span.startTimestamp, Date(timeIntervalSince1970: 4_100_000))
        XCTAssertEqual(span.timestamp, Date(timeIntervalSince1970: 4_200_000))
        XCTAssertEqual(parentSpan.timestamp, Date(timeIntervalSince1970: 4_300_000))
    }

    func testMeasureWritingData_whenIsEnabled_shouldCallBlockWithParams() throws {
        // -- Arrange --
        tracker.enable()

        // -- Act --
        var callData: Data?
        var callUrl: URL?
        var callOptions: Data.WritingOptions?
        tracker.measureWritingData(testData, to: testUrl, options: testWritingOptions, origin: testOrigin) { data, url, options in
            callData = data
            callUrl = url
            callOptions = options
        }

        // -- Assert --
        XCTAssertEqual(callData, testData)
        XCTAssertEqual(callUrl, testUrl)
        XCTAssertEqual(callOptions, testWritingOptions)
    }

    func testMeasureWritingData_whenIsNotEnabled_shouldNotCreateSpan() throws {
        // -- Arrange --
        tracker.disable()

        // -- Act --
        let transaction = hub.startTransaction(name: "Transaction", operation: "Test", bindToScope: true)
        var isCalled = false
        tracker.measureWritingData(testData, to: testUrl, options: testWritingOptions, origin: testOrigin) { _, _, _ in
            isCalled = true
        }
        transaction.finish()

        // -- Assert --
        XCTAssertTrue(isCalled)

        let parentSpan = try XCTUnwrap(transaction as? SentryTracer)
        XCTAssertEqual(parentSpan.children.count, 0)
    }

    func testMeasureWritingData_whenIsNotEnabled_shouldCallBlockWithParams() throws {
        // -- Arrange --
        tracker.disable()

        // -- Act --
        var callData: Data?
        var callUrl: URL?
        var callOptions: Data.WritingOptions?
        tracker.measureWritingData(testData, to: testUrl, options: testWritingOptions, origin: testOrigin) { data, url, options in
            callData = data
            callUrl = url
            callOptions = options
        }

        // -- Assert --
        XCTAssertEqual(callData, testData)
        XCTAssertEqual(callUrl, testUrl)
        XCTAssertEqual(callOptions, testWritingOptions)
    }

    func testMeasureWritingData_whenNonFileURL_shouldNotCreateSpan() throws {
        // -- Arrange --
        tracker.enable()

        // -- Act --
        var isCalled = false
        let transaction = hub.startTransaction(name: "Transaction", operation: "Test", bindToScope: true)
        tracker.measureWritingData(testData, to: nonFileUrl, options: testWritingOptions, origin: testOrigin) { _, _, _ in
            isCalled = true
        }
        transaction.finish()

        // -- Assert --
        let parentSpan = try XCTUnwrap(transaction as? SentryTracer)
        XCTAssertEqual(parentSpan.children.count, 0)
        XCTAssertTrue(isCalled)
    }

    func testMeasureWritingData_whenNonFileURL_shouldCallBlockWithParams() throws {
        // -- Arrange --
        tracker.enable()

        // -- Act --
        var callData: Data?
        var callUrl: URL?
        var callOptions: Data.WritingOptions?
        tracker.measureWritingData(testData, to: nonFileUrl, options: testWritingOptions, origin: testOrigin) { data, url, options in
            callData = data
            callUrl = url
            callOptions = options
        }

        // -- Assert --
        XCTAssertEqual(callData, testData)
        XCTAssertEqual(callUrl, nonFileUrl)
        XCTAssertEqual(callOptions, testWritingOptions)
    }

    func testMeasureWritingData_whenThrowsError_shouldFinishSpanWithInternalError() throws {
        // -- Arrange --
        tracker.enable()

        // -- Act --
        let transaction = hub.startTransaction(name: "Transaction", operation: "Test", bindToScope: true)
        XCTAssertThrowsError(try tracker.measureWritingData(testData, to: testUrl, options: testWritingOptions, origin: testOrigin) { _, _, _ in
            throw testError
        })
        transaction.finish()

        // -- Assert --
        let parentSpan = try XCTUnwrap(transaction as? SentryTracer)
        XCTAssertEqual(parentSpan.children.count, 1)
        let span = try XCTUnwrap(parentSpan.children.first)

        XCTAssertEqual(span.status, SentrySpanStatus.internalError)
    }

    func testMeasureWritingData_whenThrowsError_shouldRethrow() throws {
        // -- Arrange --
        tracker.enable()

        // -- Act --
        var thrownError: (any Error)?
        XCTAssertThrowsError(try tracker.measureWritingData(testData, to: testUrl, options: testWritingOptions, origin: testOrigin) { _, _, _ in
            throw testError
        }, "", { (error: any Error) in
            thrownError = error
        })

        // -- Assert --
        XCTAssertEqual(thrownError as? NSError, testError)
    }

    // MARK: - SentryFileIOTracker.measureRemovingItem(at:origin:method:)

    func testMeasureRemovingItemAtURL_whenIsEnabled_shouldCreateSpanWithOrderedTimestamps() throws {
        // -- Arrange --
        tracker.enable()

        // -- Act --
        mockedDateProvider.setDate(date: Date(timeIntervalSince1970: 4_000_000))
        let transaction = hub.startTransaction(name: "Transaction", operation: "Test", bindToScope: true)

        // Advance the time to make sure the child span has a different start time than the parent span
        mockedDateProvider.setDate(date: Date(timeIntervalSince1970: 4_100_000))
        tracker.measureRemovingItem(at: testUrl, origin: testOrigin) { _ in
            // Advance the time to make sure the child span has a different start and end time
            mockedDateProvider.setDate(date: Date(timeIntervalSince1970: 4_200_000))
        }

        // Advance the time to make sure the parent span has a different end time than the child span
        mockedDateProvider.setDate(date: Date(timeIntervalSince1970: 4_300_000))
        transaction.finish()

        // -- Assert --
        let parentSpan = try XCTUnwrap(transaction as? SentryTracer)
        XCTAssertEqual(parentSpan.children.count, 1)
        let span = try XCTUnwrap(parentSpan.children.first)

        XCTAssertEqual(span.operation, "file.delete")
        XCTAssertEqual(span.data["file.path"] as? String, testUrl.path)

        XCTAssertEqual(parentSpan.startTimestamp, Date(timeIntervalSince1970: 4_000_000))
        XCTAssertEqual(span.startTimestamp, Date(timeIntervalSince1970: 4_100_000))
        XCTAssertEqual(span.timestamp, Date(timeIntervalSince1970: 4_200_000))
        XCTAssertEqual(parentSpan.timestamp, Date(timeIntervalSince1970: 4_300_000))
    }

    func testMeasureRemovingItemAtURL_whenIsEnabled_shouldCallBlockWithParams() throws {
        // -- Arrange --
        tracker.enable()

        // -- Act --
        var callUrl: URL?
        tracker.measureRemovingItem(at: testUrl, origin: testOrigin) { url in
            callUrl = url
        }

        // -- Assert --
        XCTAssertEqual(callUrl, testUrl)
    }

    func testMeasureRemovingItemAtURL_whenIsNotEnabled_shouldNotCreateSpan() throws {
        // -- Arrange --
        tracker.disable()

        // -- Act --
        let transaction = hub.startTransaction(name: "Transaction", operation: "Test", bindToScope: true)
        var isCalled = false
        tracker.measureRemovingItem(at: testUrl, origin: testOrigin) { _ in
            isCalled = true
        }
        transaction.finish()

        // -- Assert --
        XCTAssertTrue(isCalled)

        let parentSpan = try XCTUnwrap(transaction as? SentryTracer)
        XCTAssertEqual(parentSpan.children.count, 0)
    }

    func testMeasureRemovingItemAtURL_whenIsNotEnabled_shouldCallBlockWithParams() throws {
        // -- Arrange --
        tracker.disable()

        // -- Act --
        var callUrl: URL?
        tracker.measureRemovingItem(at: testUrl, origin: testOrigin) { url in
            callUrl = url
        }

        // -- Assert --
        XCTAssertEqual(callUrl, testUrl)
    }

    func testMeasureRemovingItemAtURL_whenNonFileURL_shouldNotCreateSpan() throws {
        // -- Arrange --
        tracker.enable()

        // -- Act --
        let transaction = hub.startTransaction(name: "Transaction", operation: "Test", bindToScope: true)
        var isCalled = false
        tracker.measureRemovingItem(at: nonFileUrl, origin: testOrigin) { _ in
            isCalled = true
        }
        transaction.finish()

        // -- Assert --
        XCTAssertTrue(isCalled)

        let parentSpan = try XCTUnwrap(transaction as? SentryTracer)
        XCTAssertEqual(parentSpan.children.count, 0)
    }

    func testMeasureRemovingItemAtURL_whenNonFileURL_shouldCallBlockWithParams() throws {
        // -- Arrange --
        tracker.enable()

        // -- Act --
        var callUrl: URL?
        tracker.measureRemovingItem(at: nonFileUrl, origin: testOrigin) { url in
            callUrl = url
        }

        // -- Assert --
        XCTAssertEqual(callUrl, nonFileUrl)
    }

    func testMeasureRemovingItemAtURL_whenThrowsError_shouldFinishSpanWithInternalError() throws {
        // -- Arrange --
        tracker.enable()

        // -- Act --
        let transaction = hub.startTransaction(name: "Transaction", operation: "Test", bindToScope: true)
        XCTAssertThrowsError(try tracker.measureRemovingItem(at: testUrl, origin: testOrigin) { _ in
            throw testError
        })
        transaction.finish()

        // -- Assert --
        let parentSpan = try XCTUnwrap(transaction as? SentryTracer)
        XCTAssertEqual(parentSpan.children.count, 1)
        let span = try XCTUnwrap(parentSpan.children.first)

        XCTAssertEqual(span.status, SentrySpanStatus.internalError)
    }

    func testMeasureRemovingItemAtURL_whenThrowsError_shouldRethrow() throws {
        // -- Arrange --
        tracker.enable()

        // -- Act --
        var thrownError: (any Error)?
        XCTAssertThrowsError(try tracker.measureRemovingItem(at: testUrl, origin: testOrigin) { _ in
            throw testError
        }, "", { (error: any Error) in
            thrownError = error
        })

        // -- Assert --
        XCTAssertEqual(thrownError as? NSError, testError)
    }

    // MARK: - SentryFileIOTracker.measureRemovingItem(atPath:origin:method:)

    func testMeasureRemovingItemAtPath_whenIsEnabled_shouldCreateSpanWithOrderedTimestamps() throws {
        // -- Arrange --
        tracker.enable()

        // -- Act --
        mockedDateProvider.setDate(date: Date(timeIntervalSince1970: 4_000_000))
        let transaction = hub.startTransaction(name: "Transaction", operation: "Test", bindToScope: true)

        // Advance the time to make sure the child span has a different start time than the parent span
        mockedDateProvider.setDate(date: Date(timeIntervalSince1970: 4_100_000))
        tracker.measureRemovingItem(atPath: testPath, origin: testOrigin) { _ in
            // Advance the time to make sure the child span has a different start and end time
            mockedDateProvider.setDate(date: Date(timeIntervalSince1970: 4_200_000))
        }

        // Advance the time to make sure the parent span has a different end time than the child span
        mockedDateProvider.setDate(date: Date(timeIntervalSince1970: 4_300_000))
        transaction.finish()

        // -- Assert --
        let parentSpan = try XCTUnwrap(transaction as? SentryTracer)
        XCTAssertEqual(parentSpan.children.count, 1)
        let span = try XCTUnwrap(parentSpan.children.first)

        XCTAssertEqual(span.operation, "file.delete")
        XCTAssertEqual(span.data["file.path"] as? String, testPath)

        XCTAssertEqual(parentSpan.startTimestamp, Date(timeIntervalSince1970: 4_000_000))
        XCTAssertEqual(span.startTimestamp, Date(timeIntervalSince1970: 4_100_000))
        XCTAssertEqual(span.timestamp, Date(timeIntervalSince1970: 4_200_000))
        XCTAssertEqual(parentSpan.timestamp, Date(timeIntervalSince1970: 4_300_000))
    }

    func testMeasureRemovingItemAtPath_whenIsEnabled_shouldCallBlockWithParams() throws {
        // -- Arrange --
        tracker.enable()

        // -- Act --
        var callPath: String?
        tracker.measureRemovingItem(atPath: testPath, origin: testOrigin) { path in
            callPath = path
        }

        // -- Assert --
        XCTAssertEqual(callPath, testPath)
    }

    func testMeasureRemovingItemAtPath_whenIsNotEnabled_shouldNotCreateSpan() throws {
        // -- Arrange --
        tracker.disable()

        // -- Act --
        let transaction = hub.startTransaction(name: "Transaction", operation: "Test", bindToScope: true)
        var isCalled = false
        tracker.measureRemovingItem(atPath: testPath, origin: testOrigin) { _ in
            isCalled = true
        }
        transaction.finish()

        // -- Assert --
        XCTAssertTrue(isCalled)

        let parentSpan = try XCTUnwrap(transaction as? SentryTracer)
        XCTAssertEqual(parentSpan.children.count, 0)
    }

    func testMeasureRemovingItemAtPath_whenIsNotEnabled_shouldCallBlockWithParams() throws {
        // -- Arrange --
        tracker.disable()

        // -- Act --
        var callPath: String?
        tracker.measureRemovingItem(atPath: testPath, origin: testOrigin) { path in
            callPath = path
        }

        // -- Assert --
        XCTAssertEqual(callPath, testPath)
    }

    func testMeasureRemovingItemAtPath_whenThrowsError_shouldFinishSpanWithInternalError() throws {
        // -- Arrange --
        tracker.enable()

        // -- Act --
        let transaction = hub.startTransaction(name: "Transaction", operation: "Test", bindToScope: true)
        XCTAssertThrowsError(try tracker.measureRemovingItem(atPath: testPath, origin: testOrigin) { _ in
            throw testError
        })
        transaction.finish()

        // -- Assert --
        let parentSpan = try XCTUnwrap(transaction as? SentryTracer)
        XCTAssertEqual(parentSpan.children.count, 1)
        let span = try XCTUnwrap(parentSpan.children.first)

        XCTAssertEqual(span.status, SentrySpanStatus.internalError)
    }

    func testMeasureRemovingItemAtPath_whenThrowsError_shouldRethrow() throws {
        // -- Arrange --
        tracker.enable()

        // -- Act --
        var thrownError: (any Error)?
        XCTAssertThrowsError(try tracker.measureRemovingItem(atPath: testPath, origin: testOrigin) { _ in
            throw testError
        }, "", { (error: any Error) in
            thrownError = error
        })

        // -- Assert --
        XCTAssertEqual(thrownError as? NSError, testError)
    }

    // MARK: - SentryFileIOTracker.measureCreatingFile(atPath:contents:attributes:origin:method:)

    func testMeasureCreatingFile_whenIsEnabled_shouldCreateSpanWithOrderedTimestamps() throws {
        // -- Arrange --
        tracker.enable()

        // -- Act --
        mockedDateProvider.setDate(date: Date(timeIntervalSince1970: 4_000_000))
        let transaction = hub.startTransaction(name: "Transaction", operation: "Test", bindToScope: true)

        // Advance the time to make sure the child span has a different start time than the parent span
        mockedDateProvider.setDate(date: Date(timeIntervalSince1970: 4_100_000))
        let _ = tracker.measureCreatingFile(atPath: testPath, contents: testData, attributes: nil, origin: testOrigin) { _, _, _ in
            // Advance the time to make sure the child span has a different start and end time
            mockedDateProvider.setDate(date: Date(timeIntervalSince1970: 4_200_000))
            return true
        }

        // Advance the time to make sure the parent span has a different end time than the child span
        mockedDateProvider.setDate(date: Date(timeIntervalSince1970: 4_300_000))
        transaction.finish()

        // -- Assert --
        let parentSpan = try XCTUnwrap(transaction as? SentryTracer)
        XCTAssertEqual(parentSpan.children.count, 1)
        let span = try XCTUnwrap(parentSpan.children.first)

        XCTAssertEqual(span.operation, "file.write")
        XCTAssertEqual(span.data["file.path"] as? String, testPath)
        XCTAssertEqual(span.data["file.size"] as? Int, testData.count)

        XCTAssertEqual(parentSpan.startTimestamp, Date(timeIntervalSince1970: 4_000_000))
        XCTAssertEqual(span.startTimestamp, Date(timeIntervalSince1970: 4_100_000))
        XCTAssertEqual(span.timestamp, Date(timeIntervalSince1970: 4_200_000))
        XCTAssertEqual(parentSpan.timestamp, Date(timeIntervalSince1970: 4_300_000))
    }

    func testMeasureCreatingFile_whenIsEnabled_shouldCallBlockWithParams() throws {
        // -- Arrange --
        tracker.enable()

        // -- Act --
        var callPath: String?
        var callData: Data?
        var callAttr: [FileAttributeKey: Any]?
        let result = tracker.measureCreatingFile(atPath: testPath, contents: testData, attributes: createFileAttributes, origin: testOrigin) { path, data, attr in
            callPath = path
            callData = data
            callAttr = attr
            return true
        }

        // -- Assert --
        XCTAssertEqual(callPath, testPath)
        XCTAssertEqual(callData, testData)
        XCTAssertEqual(callAttr as? [FileAttributeKey: Date], createFileAttributes as? [FileAttributeKey: Date])
        XCTAssertEqual(result, true)
    }

    func testMeasureCreatingFile_whenIsNotEnabled_shouldNotCreateSpan() throws {
        // -- Arrange --
        tracker.disable()

        // -- Act --
        let transaction = hub.startTransaction(name: "Transaction", operation: "Test", bindToScope: true)
        var isCalled = false
        let _ = tracker.measureCreatingFile(atPath: testPath, contents: testData, attributes: nil, origin: testOrigin) { _, _, _ in
            isCalled = true
            return true
        }
        transaction.finish()

        // -- Assert --
        XCTAssertTrue(isCalled)

        let parentSpan = try XCTUnwrap(transaction as? SentryTracer)
        XCTAssertEqual(parentSpan.children.count, 0)
    }

    func testMeasureCreatingFile_whenIsNotEnabled_shouldCallBlockWithParams() throws {
        // -- Arrange --
        tracker.disable()

        // -- Act --
        var callPath: String?
        var callData: Data?
        var callAttr: [FileAttributeKey: Any]?
        let result = tracker.measureCreatingFile(atPath: testPath, contents: testData, attributes: nil, origin: testOrigin) { path, data, attr in
            callPath = path
            callData = data
            callAttr = attr
            return true
        }

        // -- Assert --
        XCTAssertEqual(callPath, testPath)
        XCTAssertEqual(callData, testData)
        XCTAssertNil(callAttr)
        XCTAssertEqual(result, true)
    }

    // MARK: - SentryFileIOTracker.measureCopyingItem(at:to:origin:method:)

    func testMeasureCopyingItemAtURL_whenIsEnabled_shouldCreateSpanWithOrderedTimestamps() throws {
        // -- Arrange --
        tracker.enable()
        let destUrl = testUrl.appendingPathComponent("dest")

        // -- Act --
        mockedDateProvider.setDate(date: Date(timeIntervalSince1970: 4_000_000))
        let transaction = hub.startTransaction(name: "Transaction", operation: "Test", bindToScope: true)

        // Advance the time to make sure the child span has a different start time than the parent span
        mockedDateProvider.setDate(date: Date(timeIntervalSince1970: 4_100_000))
        tracker.measureCopyingItem(at: testUrl, to: destUrl, origin: testOrigin) { _, _ in
            // Advance the time to make sure the child span has a different start and end time
            mockedDateProvider.setDate(date: Date(timeIntervalSince1970: 4_200_000))
        }

        // Advance the time to make sure the parent span has a different end time than the child span
        mockedDateProvider.setDate(date: Date(timeIntervalSince1970: 4_300_000))
        transaction.finish()

        // -- Assert --
        let parentSpan = try XCTUnwrap(transaction as? SentryTracer)
        XCTAssertEqual(parentSpan.children.count, 1)
        let span = try XCTUnwrap(parentSpan.children.first)

        XCTAssertEqual(span.operation, "file.copy")
        XCTAssertEqual(span.data["file.path"] as? String, testUrl.path)

        XCTAssertEqual(parentSpan.startTimestamp, Date(timeIntervalSince1970: 4_000_000))
        XCTAssertEqual(span.startTimestamp, Date(timeIntervalSince1970: 4_100_000))
        XCTAssertEqual(span.timestamp, Date(timeIntervalSince1970: 4_200_000))
        XCTAssertEqual(parentSpan.timestamp, Date(timeIntervalSince1970: 4_300_000))
    }

    func testMeasureCopyingItemAtURL_whenIsEnabled_shouldCallBlockWithParams() throws {
        // -- Arrange --
        tracker.enable()

        // -- Act --
        var callSrc: URL?
        var callDst: URL?
        tracker.measureCopyingItem(at: testUrl, to: destUrl, origin: testOrigin) { src, dst in
            callSrc = src
            callDst = dst
        }

        // -- Assert --
        XCTAssertEqual(callSrc, testUrl)
        XCTAssertEqual(callDst, destUrl)
    }

    func testMeasureCopyingItemAtURL_whenIsNotEnabled_shouldNotCreateSpan() throws {
        // -- Arrange --
        tracker.disable()

        // -- Act --
        let transaction = hub.startTransaction(name: "Transaction", operation: "Test", bindToScope: true)
        var isCalled = false
        tracker.measureCopyingItem(at: testUrl, to: destUrl, origin: testOrigin) { _, _ in
            isCalled = true
        }

        // -- Assert --
        XCTAssertTrue(isCalled)

        let parentSpan = try XCTUnwrap(transaction as? SentryTracer)
        XCTAssertEqual(parentSpan.children.count, 0)
    }

    func testMeasureCopyingItemAtURL_whenIsNotEnabled_shouldCallBlockWithParams() throws {
        // -- Arrange --
        tracker.disable()

        // -- Act --
        var callSrc: URL?
        var callDst: URL?
        tracker.measureCopyingItem(at: testUrl, to: destUrl, origin: testOrigin) { src, dst in
            callSrc = src
            callDst = dst
        }

        // -- Assert --
        XCTAssertEqual(callSrc, testUrl)
        XCTAssertEqual(callDst, destUrl)
    }

    func testMeasureCopyingItemAtURL_whenSrcIsNonFileURL_shouldNotCreateSpan() throws {
        // -- Arrange --
        tracker.enable()

        // -- Act --
        let transaction = hub.startTransaction(name: "Transaction", operation: "Test", bindToScope: true)
        var isCalled = false
        tracker.measureCopyingItem(at: nonFileUrl, to: destUrl, origin: testOrigin) { _, _ in
            isCalled = true
        }
        transaction.finish()

        // -- Assert --
        XCTAssertTrue(isCalled)

        let parentSpan = try XCTUnwrap(transaction as? SentryTracer)
        XCTAssertEqual(parentSpan.children.count, 0)
    }

    func testMeasureCopyingItemAtURL_whenSrcIsNonFileURL_shouldCallBlockWithParams() throws {
        // -- Arrange --
        tracker.enable()

        // -- Act --
        var callSrc: URL?
        var callDst: URL?
        tracker.measureCopyingItem(at: nonFileUrl, to: destUrl, origin: testOrigin) { src, dst in
            callSrc = src
            callDst = dst
        }

        // -- Assert --
        XCTAssertEqual(callSrc, nonFileUrl)
        XCTAssertEqual(callDst, destUrl)
    }

    func testMeasureCopyingItemAtURL_whenDstIsNonFileURL_shouldNotCreateSpan() throws {
        // -- Arrange --
        tracker.enable()

        // -- Act --
        let transaction = hub.startTransaction(name: "Transaction", operation: "Test", bindToScope: true)
        var isCalled = false
        tracker.measureCopyingItem(at: testUrl, to: nonFileUrl, origin: testOrigin) { _, _ in
            isCalled = true
        }
        transaction.finish()

        // -- Assert --
        XCTAssertTrue(isCalled)

        let parentSpan = try XCTUnwrap(transaction as? SentryTracer)
        XCTAssertEqual(parentSpan.children.count, 0)
    }

    func testMeasureCopyingItemAtURL_whenDstIsNonFileURL_shouldCallBlockWithParams() throws {
        // -- Arrange --
        tracker.enable()

        // -- Act --
        var callSrc: URL?
        var callDst: URL?
        tracker.measureCopyingItem(at: testUrl, to: nonFileUrl, origin: testOrigin) { src, dst in
            callSrc = src
            callDst = dst
        }

        // -- Assert --
        XCTAssertEqual(callSrc, testUrl)
        XCTAssertEqual(callDst, nonFileUrl)
    }

    func testMeasureCopyingItemAtURL_whenThrowsError_shouldFinishSpanWithInternalError() throws {
        // -- Arrange --
        tracker.enable()

        // -- Act --
        let transaction = hub.startTransaction(name: "Transaction", operation: "Test", bindToScope: true)
        XCTAssertThrowsError(try tracker.measureCopyingItem(at: testUrl, to: destUrl, origin: testOrigin) { _, _ in
            throw testError
        })
        transaction.finish()

        // -- Assert --
        let parentSpan = try XCTUnwrap(transaction as? SentryTracer)
        XCTAssertEqual(parentSpan.children.count, 1)
        let span = try XCTUnwrap(parentSpan.children.first)

        XCTAssertEqual(span.status, SentrySpanStatus.internalError)
    }

    func testMeasureCopyingItemAtURL_whenThrowsError_shouldRethrow() throws {
        // -- Arrange --
        tracker.enable()

        // -- Act --
        var thrownError: (any Error)?
        XCTAssertThrowsError(try tracker.measureCopyingItem(at: testUrl, to: destUrl, origin: testOrigin) { _, _ in
            throw testError
        }, "", { (error: any Error) in
            thrownError = error
        })

        // -- Assert --
        XCTAssertEqual(thrownError as? NSError, testError)
    }

    // MARK: - SentryFileIOTracker.measureCopyingItem(atPath:toPath:origin:method:)

    func testMeasureCopyingItemAtPath_whenIsEnabled_shouldCreateSpanWithOrderedTimestamps() throws {
        // -- Arrange --
        tracker.enable()

        // -- Act --
        mockedDateProvider.setDate(date: Date(timeIntervalSince1970: 4_000_000))
        let transaction = hub.startTransaction(name: "Transaction", operation: "Test", bindToScope: true)

        // Advance the time to make sure the child span has a different start time than the parent span
        mockedDateProvider.setDate(date: Date(timeIntervalSince1970: 4_100_000))
        tracker.measureCopyingItem(atPath: testPath, toPath: destPath, origin: testOrigin) { _, _ in
            // Advance the time to make sure the child span has a different start and end time
            mockedDateProvider.setDate(date: Date(timeIntervalSince1970: 4_200_000))
        }

        // Advance the time to make sure the parent span has a different end time than the child span
        mockedDateProvider.setDate(date: Date(timeIntervalSince1970: 4_300_000))
        transaction.finish()

        // -- Assert --
        let parentSpan = try XCTUnwrap(transaction as? SentryTracer)
        XCTAssertEqual(parentSpan.children.count, 1)
        let span = try XCTUnwrap(parentSpan.children.first)

        XCTAssertEqual(span.status, SentrySpanStatus.ok)
        XCTAssertEqual(span.origin, testOrigin)
        XCTAssertEqual(span.operation, SentrySpanOperationFileCopy)
        XCTAssertEqual(span.data["file.path"] as? String, testPath)

        XCTAssertEqual(parentSpan.startTimestamp, Date(timeIntervalSince1970: 4_000_000))
        XCTAssertEqual(span.startTimestamp, Date(timeIntervalSince1970: 4_100_000))
        XCTAssertEqual(span.timestamp, Date(timeIntervalSince1970: 4_200_000))
        XCTAssertEqual(parentSpan.timestamp, Date(timeIntervalSince1970: 4_300_000))
    }

    func testMeasureCopyingItemAtPath_whenIsEnabled_shouldCallBlockWithParams() throws {
        // -- Arrange --
        tracker.enable()

        // -- Act --
        var callSrc: String?
        var callDst: String?
        tracker.measureCopyingItem(atPath: testPath, toPath: destPath, origin: testOrigin) { src, dst in
            callSrc = src
            callDst = dst
        }

        // -- Assert --
        XCTAssertEqual(callSrc, testPath)
        XCTAssertEqual(callDst, destPath)
    }

    func testMeasureCopyingItemAtPath_whenIsNotEnabled_shouldNotCreateSpan() throws {
        // -- Arrange --
        tracker.disable()

        // -- Act --
        let transaction = hub.startTransaction(name: "Transaction", operation: "Test", bindToScope: true)
        var isCalled = false
        tracker.measureCopyingItem(atPath: testPath, toPath: destPath, origin: testOrigin) { _, _ in
            isCalled = true
        }
        transaction.finish()

        // -- Assert --
        XCTAssertTrue(isCalled)

        let parentSpan = try XCTUnwrap(transaction as? SentryTracer)
        XCTAssertEqual(parentSpan.children.count, 0)
    }

    func testMeasureCopyingItemAtPath_whenIsNotEnabled_shouldCallBlockWithParams() throws {
        // -- Arrange --
        tracker.disable()

        // -- Act --
        var callSrc: String?
        var callDst: String?
        tracker.measureCopyingItem(atPath: testPath, toPath: destPath, origin: testOrigin) { src, dst in
            callSrc = src
            callDst = dst
        }

        // -- Assert --
        XCTAssertEqual(callSrc, testPath)
        XCTAssertEqual(callDst, destPath)
    }

    func testMeasureCopyingItemAtPath_whenThrowsError_shouldFinishSpanWithInternalError() throws {
        // -- Arrange --
        tracker.enable()

        // -- Act --
        let transaction = hub.startTransaction(name: "Transaction", operation: "Test", bindToScope: true)
        XCTAssertThrowsError(try tracker.measureCopyingItem(atPath: testPath, toPath: destPath, origin: testOrigin) { _, _ in
            throw testError
        })
        transaction.finish()

        // -- Assert --
        let parentSpan = try XCTUnwrap(transaction as? SentryTracer)
        XCTAssertEqual(parentSpan.children.count, 1)
        let span = try XCTUnwrap(parentSpan.children.first)

        XCTAssertEqual(span.status, SentrySpanStatus.internalError)
    }

    func testMeasureCopyingItemAtPath_whenThrowsError_shouldRethrow() throws {
        // -- Arrange --
        tracker.enable()

        // -- Act --
        var thrownError: (any Error)?
        XCTAssertThrowsError(try tracker.measureCopyingItem(atPath: testPath, toPath: destPath, origin: testOrigin) { _, _ in
            throw testError
        }, "", { (error: any Error) in
            thrownError = error
        })

        // -- Assert --
        XCTAssertEqual(thrownError as? NSError, testError)
    }

    // MARK: - SentryFileIOTracker.measureMovingItem(at:to:origin:method:)

    func testMeasureMovingItemAtURL_whenIsEnabled_shouldCreateSpanWithOrderedTimestamps() throws {
        // -- Arrange --
        tracker.enable()

        // -- Act --
        mockedDateProvider.setDate(date: Date(timeIntervalSince1970: 4_000_000))
        let transaction = hub.startTransaction(name: "Transaction", operation: "Test", bindToScope: true)

        // Advance the time to make sure the child span has a different start time than the parent span
        mockedDateProvider.setDate(date: Date(timeIntervalSince1970: 4_100_000))
        tracker.measureMovingItem(at: testUrl, to: destUrl, origin: testOrigin) { _, _ in
            // Advance the time to make sure the child span has a different start and end time
            mockedDateProvider.setDate(date: Date(timeIntervalSince1970: 4_200_000))
        }

        // Advance the time to make sure the parent span has a different end time than the child span
        mockedDateProvider.setDate(date: Date(timeIntervalSince1970: 4_300_000))
        transaction.finish()

        // -- Assert --
        let parentSpan = try XCTUnwrap(transaction as? SentryTracer)
        XCTAssertEqual(parentSpan.children.count, 1)
        let span = try XCTUnwrap(parentSpan.children.first)

        XCTAssertEqual(span.operation, "file.rename")
        XCTAssertEqual(span.data["file.path"] as? String, testUrl.path)

        XCTAssertEqual(parentSpan.startTimestamp, Date(timeIntervalSince1970: 4_000_000))
        XCTAssertEqual(span.startTimestamp, Date(timeIntervalSince1970: 4_100_000))
        XCTAssertEqual(span.timestamp, Date(timeIntervalSince1970: 4_200_000))
        XCTAssertEqual(parentSpan.timestamp, Date(timeIntervalSince1970: 4_300_000))
    }

    func testMeasureMovingItemAtURL_whenIsEnabled_shouldCallBlockWithParams() throws {
        // -- Arrange --
        tracker.enable()

        // -- Act --
        var callSrc: URL?
        var callDst: URL?
        tracker.measureMovingItem(at: testUrl, to: destUrl, origin: testOrigin) { src, dst in
            callSrc = src
            callDst = dst
        }

        // -- Assert --
        XCTAssertEqual(callSrc, testUrl)
        XCTAssertEqual(callDst, destUrl)
    }

    func testMeasureMovingItemAtURL_whenIsNotEnabled_shouldNotCreateSpan() throws {
        // -- Arrange --
        tracker.disable()

        // -- Act --
        let transaction = hub.startTransaction(name: "Transaction", operation: "Test", bindToScope: true)
        var isCalled = false
        tracker.measureMovingItem(at: testUrl, to: destUrl, origin: testOrigin) { _, _ in
            isCalled = true
        }
        transaction.finish()

        // -- Assert --
        XCTAssertTrue(isCalled)

        let parentSpan = try XCTUnwrap(transaction as? SentryTracer)
        XCTAssertEqual(parentSpan.children.count, 0)
    }

    func testMeasureMovingItemAtURL_whenIsNotEnabled_shouldCallBlockWithParams() throws {
        // -- Arrange --
        tracker.disable()

        // -- Act --
        var callSrc: URL?
        var callDst: URL?
        tracker.measureMovingItem(at: testUrl, to: destUrl, origin: testOrigin) { src, dst in
            callSrc = src
            callDst = dst
        }

        // -- Assert --
        XCTAssertEqual(callSrc, testUrl)
        XCTAssertEqual(callDst, destUrl)
    }

    func testMeasureMovingItemAtURL_whenSrcIsNonFileURL_shouldNotCreateSpan() throws {
        // -- Arrange --
        tracker.enable()

        // -- Act --
        let transaction = hub.startTransaction(name: "Transaction", operation: "Test", bindToScope: true)
        var isCalled = false
        tracker.measureMovingItem(at: nonFileUrl, to: destUrl, origin: testOrigin) { _, _ in
            isCalled = true
        }

        // -- Assert --
        XCTAssertTrue(isCalled)

        let parentSpan = try XCTUnwrap(transaction as? SentryTracer)
        XCTAssertEqual(parentSpan.children.count, 0)
    }

    func testMeasureMovingItemAtURL_whenSrcIsNonFileURL_shouldCallBlockWithParams() throws {
        // -- Arrange --
        tracker.enable()

        // -- Act --
        var callSrc: URL?
        var callDst: URL?
        tracker.measureMovingItem(at: nonFileUrl, to: destUrl, origin: testOrigin) { src, dst in
            callSrc = src
            callDst = dst
        }

        // -- Assert --
        XCTAssertEqual(callSrc, nonFileUrl)
        XCTAssertEqual(callDst, destUrl)
    }

    func testMeasureMovingItemAtURL_whenDstIsNonFileURL_shouldNotCreateSpan() throws {
        // -- Arrange --
        tracker.enable()

        // -- Act --
        let transaction = hub.startTransaction(name: "Transaction", operation: "Test", bindToScope: true)
        var isCalled = false
        tracker.measureMovingItem(at: testUrl, to: nonFileUrl, origin: testOrigin) { _, _ in
            isCalled = true
        }

        // -- Assert --
        XCTAssertTrue(isCalled)

        let parentSpan = try XCTUnwrap(transaction as? SentryTracer)
        XCTAssertEqual(parentSpan.children.count, 0)
    }

    func testMeasureMovingItemAtURL_whenDstIsNonFileURL_shouldCallBlockWithParams() throws {
        // -- Arrange --
        tracker.enable()

        // -- Act --
        var callSrc: URL?
        var callDst: URL?
        tracker.measureMovingItem(at: testUrl, to: nonFileUrl, origin: testOrigin) { src, dst in
            callSrc = src
            callDst = dst
        }

        // -- Assert --
        XCTAssertEqual(callSrc, testUrl)
        XCTAssertEqual(callDst, nonFileUrl)
    }

    func testMeasureMovingItemAtURL_whenThrowsError_shouldFinishSpanWithInternalError() throws {
        // -- Arrange --
        tracker.enable()

        // -- Act --
        let transaction = hub.startTransaction(name: "Transaction", operation: "Test", bindToScope: true)
        XCTAssertThrowsError(try tracker.measureMovingItem(at: testUrl, to: destUrl, origin: testOrigin) { _, _ in
            throw testError
        })
        transaction.finish()

        // -- Assert --
        let parentSpan = try XCTUnwrap(transaction as? SentryTracer)
        XCTAssertEqual(parentSpan.children.count, 1)
        let span = try XCTUnwrap(parentSpan.children.first)

        XCTAssertEqual(span.status, SentrySpanStatus.internalError)
    }

    func testMeasureMovingItemAtURL_whenThrowsError_shouldRethrow() throws {
        // -- Arrange --
        tracker.enable()

        // -- Act --
        var thrownError: (any Error)?
        XCTAssertThrowsError(try tracker.measureMovingItem(at: testUrl, to: destUrl, origin: testOrigin) { _, _ in
            throw testError
        }, "", { (error: any Error) in
            thrownError = error
        })

        // -- Assert --
        XCTAssertEqual(thrownError as? NSError, testError)
    }

    // MARK: - SentryFileIOTracker.measureMovingItem(atPath:toPath:origin:method:)

    func testMeasureMovingItemAtPath_whenIsEnabled_shouldCreateSpanWithOrderedTimestamps() throws {
        // -- Arrange --
        tracker.enable()

        // -- Act --
        mockedDateProvider.setDate(date: Date(timeIntervalSince1970: 4_000_000))
        let transaction = hub.startTransaction(name: "Transaction", operation: "Test", bindToScope: true)

        // Advance the time to make sure the child span has a different start time than the parent span
        mockedDateProvider.setDate(date: Date(timeIntervalSince1970: 4_100_000))
        tracker.measureMovingItem(atPath: testPath, toPath: destPath, origin: testOrigin) { _, _ in
            // Advance the time to make sure the child span has a different start and end time
            mockedDateProvider.setDate(date: Date(timeIntervalSince1970: 4_200_000))
        }

        // Advance the time to make sure the parent span has a different end time than the child span
        mockedDateProvider.setDate(date: Date(timeIntervalSince1970: 4_300_000))
        transaction.finish()

        // -- Assert --
        let parentSpan = try XCTUnwrap(transaction as? SentryTracer)
        XCTAssertEqual(parentSpan.children.count, 1)
        let span = try XCTUnwrap(parentSpan.children.first)

        XCTAssertEqual(span.status, SentrySpanStatus.ok)
        XCTAssertEqual(span.origin, testOrigin)
        XCTAssertEqual(span.operation, SentrySpanOperationFileRename)
        XCTAssertEqual(span.data["file.path"] as? String, testPath)

        XCTAssertEqual(parentSpan.startTimestamp, Date(timeIntervalSince1970: 4_000_000))
        XCTAssertEqual(span.startTimestamp, Date(timeIntervalSince1970: 4_100_000))
        XCTAssertEqual(span.timestamp, Date(timeIntervalSince1970: 4_200_000))
        XCTAssertEqual(parentSpan.timestamp, Date(timeIntervalSince1970: 4_300_000))
    }

    func testMeasureMovingItemAtPath_whenIsEnabled_shouldCallBlockWithParams() throws {
        // -- Arrange --
        tracker.enable()

        // -- Act --
        var callSrc: String?
        var callDst: String?
        tracker.measureMovingItem(atPath: testPath, toPath: destPath, origin: testOrigin) { src, dst in
            callSrc = src
            callDst = dst
        }

        // -- Assert --
        XCTAssertEqual(callSrc, testPath)
        XCTAssertEqual(callDst, destPath)
    }

    func testMeasureMovingItemAtPath_whenIsNotEnabled_shouldNotCreateSpan() throws {
        // -- Arrange --
        tracker.disable()

        // -- Act --
        let transaction = hub.startTransaction(name: "Transaction", operation: "Test", bindToScope: true)
        var isCalled = false
        tracker.measureMovingItem(atPath: testPath, toPath: destPath, origin: testOrigin) { _, _ in
            isCalled = true
        }
        transaction.finish()

        // -- Assert --
        XCTAssertTrue(isCalled)

        let parentSpan = try XCTUnwrap(transaction as? SentryTracer)
        XCTAssertEqual(parentSpan.children.count, 0)
    }

    func testMeasureMovingItemAtPath_whenIsNotEnabled_shouldCallBlockWithParams() throws {
        // -- Arrange --
        tracker.disable()

        // -- Act --
        var callSrc: String?
        var callDst: String?
        tracker.measureMovingItem(atPath: testPath, toPath: destPath, origin: testOrigin) { src, dst in
            callSrc = src
            callDst = dst
        }

        // -- Assert --
        XCTAssertEqual(callSrc, testPath)
        XCTAssertEqual(callDst, destPath)
    }

    func testMeasureMovingItemAtPath_whenThrowsError_shouldFinishSpanWithInternalError() throws {
        // -- Arrange --
        tracker.enable()

        // -- Act --
        let transaction = hub.startTransaction(name: "Transaction", operation: "Test", bindToScope: true)
        XCTAssertThrowsError(try tracker.measureMovingItem(atPath: testPath, toPath: destPath, origin: testOrigin) { _, _ in
            throw testError
        })
        transaction.finish()

        // -- Assert --
        let parentSpan = try XCTUnwrap(transaction as? SentryTracer)
        XCTAssertEqual(parentSpan.children.count, 1)
        let span = try XCTUnwrap(parentSpan.children.first)

        XCTAssertEqual(span.status, SentrySpanStatus.internalError)
    }

    func testMeasureMovingItemAtPath_whenThrowsError_shouldRethrow() throws {
        // -- Arrange --
        tracker.enable()

        // -- Act --
        var thrownError: (any Error)?
        XCTAssertThrowsError(try tracker.measureMovingItem(atPath: testPath, toPath: destPath, origin: testOrigin) { _, _ in
            throw testError
        }, "", { (error: any Error) in
            thrownError = error
        })

        // -- Assert --
        XCTAssertEqual(thrownError as? NSError, testError)
    }
}
// swiftlint:enable file_length
