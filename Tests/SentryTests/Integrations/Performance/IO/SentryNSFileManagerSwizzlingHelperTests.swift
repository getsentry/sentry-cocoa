import Foundation
@_spi(Private) @testable import Sentry
import SentryTestUtils
import XCTest

// MARK: - Tests

final class SentryNSFileManagerSwizzlingHelperTests: XCTestCase {

    private var filePath: String!
    private var fileUrl: URL!
    private var testData: Data!
    private var fileDirectory: URL!
    private var deleteFileDirectory = false
    private var mockTracker: MockFileIOTracker!

    override func setUpWithError() throws {
        try super.setUpWithError()

        let directories = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        fileDirectory = directories.first!

        if !FileManager.default.fileExists(atPath: fileDirectory.path) {
            deleteFileDirectory = true
            try FileManager.default.createDirectory(
                at: fileDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }

        fileUrl = fileDirectory.appendingPathComponent("SentryNSFileManagerSwizzlingTestFile")
        filePath = fileUrl.path

        testData = Data("TEST DATA FOR FILE MANAGER SWIZZLING".utf8)

        // Initialize mock tracker
        mockTracker = MockFileIOTracker()
        mockTracker.enable()
    }

    override func tearDownWithError() throws {
        mockTracker.disable()
        SentryNSFileManagerSwizzlingHelper.stop()

        XCTAssertFalse(SentryNSFileManagerSwizzlingHelper.swizzlingActive(), "Swizzling should be inactive after stop called")

        if FileManager.default.fileExists(atPath: fileUrl.path) {
            try FileManager.default.removeItem(at: fileUrl)
        }
        if deleteFileDirectory {
            try FileManager.default.removeItem(at: fileDirectory)
        }

        super.tearDown()
    }

    private func swizzle() {
        SentryNSFileManagerSwizzlingHelper.swizzle(withTracker: mockTracker as Any)

        XCTAssertTrue(SentryNSFileManagerSwizzlingHelper.swizzlingActive(), "Swizzling should be active after swizzle call")
    }

    // MARK: - Create File Tests

    func testCreateFileAtPath_iOS18macOS15tvOS18OrLater_whenSwizzled_shouldCallTracker() throws {
        guard #available(iOS 18, macOS 15, tvOS 18, *) else {
            throw XCTSkip("Test only targets iOS 18, macOS 15, tvOS 18 or later")
        }

        // -- Arrange --
        swizzle()
        XCTAssertEqual(mockTracker.createFileCalls.count, 0, "Should start with no create file calls")

        // -- Act --
        let success = FileManager.default.createFile(atPath: filePath, contents: testData, attributes: nil)

        // -- Assert --
        XCTAssertTrue(success, "createFile should succeed")
        XCTAssertEqual(mockTracker.createFileCalls.count, 1, "Should record one create file call")

        let call = mockTracker.createFileCalls[0]
        XCTAssertEqual(call.data, testData, "Should record correct data")
        XCTAssertEqual(call.path, filePath, "Should record correct path")

        try assertFileContainsTestData()
    }

    func testCreateFileAtPath_iOS18macOS15tvOS18OrLater_withAttributes_shouldCallTracker() throws {
        guard #available(iOS 18, macOS 15, tvOS 18, *) else {
            throw XCTSkip("Test only targets iOS 18, macOS 15, tvOS 18 or later")
        }

        // -- Arrange --
        swizzle()
        let attributes: [FileAttributeKey: Any] = [.posixPermissions: 0o644]
        XCTAssertEqual(mockTracker.createFileCalls.count, 0, "Should start with no create file calls")

        // -- Act --
        let success = FileManager.default.createFile(atPath: filePath, contents: testData, attributes: attributes)

        // -- Assert --
        XCTAssertTrue(success, "createFile should succeed")
        XCTAssertEqual(mockTracker.createFileCalls.count, 1, "Should record one create file call")

        let call = mockTracker.createFileCalls[0]
        XCTAssertEqual(call.data, testData, "Should record correct data")
        XCTAssertEqual(call.path, filePath, "Should record correct path")
        XCTAssertEqual(call.attributes?.count, 1, "Should record attributes")

        try assertFileContainsTestData()
    }

    func testCreateFileAtPath_iOS18macOS15tvOS18OrLater_whenFileFails_shouldCallTracker() throws {
        guard #available(iOS 18, macOS 15, tvOS 18, *) else {
            throw XCTSkip("Test only targets iOS 18, macOS 15, tvOS 18 or later")
        }

        // -- Arrange --
        swizzle()
        let invalidPath = "/invalid/path/that/does/not/exist/testfile.txt"
        XCTAssertEqual(mockTracker.createFileCalls.count, 0, "Should start with no create file calls")

        // -- Act --
        let success = FileManager.default.createFile(atPath: invalidPath, contents: testData, attributes: nil)

        // -- Assert --
        XCTAssertFalse(success, "createFile should fail with invalid path")
        // Should still call tracker even when the operation fails
        XCTAssertEqual(mockTracker.createFileCalls.count, 1, "Should record create file call even on failure")
        XCTAssertEqual(mockTracker.createFileCalls[0].path, invalidPath, "Should record the invalid path")
    }

    func testCreateFileAtPath_preiOS18macOS15tvOS18_whenSwizzled_shouldNotCallTracker() throws {
        if #available(iOS 18, macOS 15, tvOS 18, *) {
            throw XCTSkip("Test only targets pre iOS 18, macOS 15, tvOS 18")
        }

        // -- Arrange --
        swizzle()
        XCTAssertEqual(mockTracker.createFileCalls.count, 0, "Should start with no create file calls")

        // -- Act --
        let success = FileManager.default.createFile(atPath: filePath, contents: testData, attributes: nil)

        // -- Assert --
        XCTAssertTrue(success, "createFile should succeed")
        XCTAssertEqual(mockTracker.createFileCalls.count, 0, "Should not call tracker on pre iOS 18/macOS 15/tvOS 18")

        try assertFileContainsTestData()
    }

    // MARK: - Swizzling State Tests

    func testSwizzlingActive_whenSwizzled_shouldBeTrue() throws {
        guard #available(iOS 18, macOS 15, tvOS 18, *) else {
            throw XCTSkip("Test only targets iOS 18, macOS 15, tvOS 18 or later")
        }

        // -- Arrange & Act --
        swizzle()

        // -- Assert --
        XCTAssertTrue(SentryNSFileManagerSwizzlingHelper.swizzlingActive(), "Swizzling should be active after swizzle call")
    }

    func testSwizzlingActive_whenStopCalled_shouldBeFalse() throws {
        guard #available(iOS 18, macOS 15, tvOS 18, *) else {
            throw XCTSkip("Test only targets iOS 18, macOS 15, tvOS 18 or later")
        }

        // -- Arrange --
        swizzle()
        XCTAssertTrue(SentryNSFileManagerSwizzlingHelper.swizzlingActive(), "Swizzling should initially be active")

        // -- Act --
        SentryNSFileManagerSwizzlingHelper.stop()

        // -- Assert --
        XCTAssertFalse(SentryNSFileManagerSwizzlingHelper.swizzlingActive(), "Swizzling should be inactive after stop called")

        // Re-enable for proper tearDown
        SentryNSFileManagerSwizzlingHelper.swizzle(withTracker: mockTracker as Any)
    }

    // MARK: - Stop Tests

    func testStop_whenCalled_shouldStopTrackingCalls() throws {
        guard #available(iOS 18, macOS 15, tvOS 18, *) else {
            throw XCTSkip("Test only targets iOS 18, macOS 15, tvOS 18 or later")
        }

        // -- Arrange --
        swizzle()
        XCTAssertEqual(mockTracker.createFileCalls.count, 0, "Should start with no create file calls")

        // Verify swizzling is working first
        _ = FileManager.default.createFile(atPath: filePath, contents: testData, attributes: nil)
        XCTAssertEqual(mockTracker.createFileCalls.count, 1, "Should track call when swizzled")
        try FileManager.default.removeItem(at: fileUrl)

        // -- Act --
        SentryNSFileManagerSwizzlingHelper.stop()
        let success = FileManager.default.createFile(atPath: filePath, contents: testData, attributes: nil)

        // -- Assert --
        XCTAssertTrue(success, "createFile should succeed")
        XCTAssertEqual(mockTracker.createFileCalls.count, 1, "Should not track new calls after stop called")
        try assertFileContainsTestData()
    }

    func testStop_whenCalledMultipleTimes_shouldNotCrash() throws {
        guard #available(iOS 18, macOS 15, tvOS 18, *) else {
            throw XCTSkip("Test only targets iOS 18, macOS 15, tvOS 18 or later")
        }

        // -- Arrange --
        swizzle()

        // -- Act & Assert --
        // Should not crash when stop called multiple times
        SentryNSFileManagerSwizzlingHelper.stop()
        SentryNSFileManagerSwizzlingHelper.stop()
        SentryNSFileManagerSwizzlingHelper.stop()
    }

    // MARK: - Multiple Operations

    func testMultipleCreateFile_whenSwizzled_shouldRecordAllCalls() throws {
        guard #available(iOS 18, macOS 15, tvOS 18, *) else {
            throw XCTSkip("Test only targets iOS 18, macOS 15, tvOS 18 or later")
        }

        // -- Arrange --
        swizzle()
        let file1Path = fileDirectory.appendingPathComponent("file1.txt").path
        let file2Path = fileDirectory.appendingPathComponent("file2.txt").path
        let file3Path = fileDirectory.appendingPathComponent("file3.txt").path
        XCTAssertEqual(mockTracker.createFileCalls.count, 0, "Should start with no create file calls")

        // -- Act --
        _ = FileManager.default.createFile(atPath: file1Path, contents: testData, attributes: nil)
        _ = FileManager.default.createFile(atPath: file2Path, contents: testData, attributes: nil)
        _ = FileManager.default.createFile(atPath: file3Path, contents: testData, attributes: nil)

        // -- Assert --
        XCTAssertEqual(mockTracker.createFileCalls.count, 3, "Should record three create file calls")

        XCTAssertEqual(mockTracker.createFileCalls[0].path, file1Path, "First call should be to file1")
        XCTAssertEqual(mockTracker.createFileCalls[1].path, file2Path, "Second call should be to file2")
        XCTAssertEqual(mockTracker.createFileCalls[2].path, file3Path, "Third call should be to file3")

        // Cleanup
        try FileManager.default.removeItem(atPath: file1Path)
        try FileManager.default.removeItem(atPath: file2Path)
        try FileManager.default.removeItem(atPath: file3Path)
    }

    // MARK: - Helper Methods

    private func assertFileContainsTestData() throws {
        let writtenData = try Data(contentsOf: fileUrl)
        XCTAssertEqual(writtenData, testData, "File should contain the test data")
    }
}

// MARK: - Mock Tracker

private class MockFileIOTracker: NSObject {
    struct CreateFileCall {
        let path: String
        let data: Data
        let attributes: [FileAttributeKey: Any]?
    }

    var createFileCalls: [CreateFileCall] = []

    func enable() {
        // No-op for mock
    }

    func disable() {
        // No-op for mock
    }

    @objc func measureNSFileManagerCreateFileAtPath(
        _ path: String,
        data: Data,
        attributes: [FileAttributeKey: Any]?,
        origin: String,
        method: @escaping (String, Data, [FileAttributeKey: Any]?) -> Bool
    ) -> Bool {
        createFileCalls.append(CreateFileCall(path: path, data: data, attributes: attributes))
        return method(path, data, attributes)
    }
}
