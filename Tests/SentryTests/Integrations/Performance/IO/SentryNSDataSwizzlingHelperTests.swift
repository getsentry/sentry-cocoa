import Foundation
@_spi(Private) @testable import Sentry
import SentryTestUtils
import XCTest

// MARK: - Tests

final class SentryNSDataSwizzlingHelperTests: XCTestCase {

    private var filePath: String!
    private var fileUrl: URL!
    private var testData: Data!
    private var fileDirectory: URL!
    private var deleteFileDirectory = false
    private var mockTracker: MockFileIOTracker!

    override func setUp() {
        super.setUp()

        let directories = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        fileDirectory = directories.first!

        if !FileManager.default.fileExists(atPath: fileDirectory.path) {
            deleteFileDirectory = true
            try? FileManager.default.createDirectory(
                at: fileDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }

        fileUrl = fileDirectory.appendingPathComponent("SentryNSDataSwizzlingTestFile")
        filePath = fileUrl.path

        testData = Data("TEST DATA FOR SWIZZLING".utf8)

        // Initialize mock tracker
        mockTracker = MockFileIOTracker()
        mockTracker.enable()
    }

    override func tearDown() {
        mockTracker.disable()
        SentryNSDataSwizzlingHelper.unswizzle()

        XCTAssertFalse(SentryNSDataSwizzlingHelper.swizzlingActive(), "Swizzling should be inactive after unswizzle")

        try? FileManager.default.removeItem(at: fileUrl)
        if deleteFileDirectory {
            try? FileManager.default.removeItem(at: fileDirectory)
        }

        super.tearDown()
    }
    
    private func swizzle() {
        SentryNSDataSwizzlingHelper.swizzle(withTracker: mockTracker as Any)

        XCTAssertTrue(SentryNSDataSwizzlingHelper.swizzlingActive(), "Swizzling should be active after swizzle call")
    }

    // MARK: - Write Methods

    func testWriteToFileAtomically_whenSwizzled_shouldCallTracker() throws {
        // -- Arrange --
        swizzle()
        XCTAssertEqual(mockTracker.writeCalls.count, 0, "Should start with no write calls")

        // -- Act --
        let success = (testData as NSData).write(toFile: filePath, atomically: true)

        // -- Assert --
        XCTAssertTrue(success, "writeToFile:atomically: should succeed")
        XCTAssertEqual(mockTracker.writeCalls.count, 1, "Should record one write call")

        let call = mockTracker.writeCalls[0]
        XCTAssertEqual(call.data, testData, "Should record correct data")
        XCTAssertEqual(call.path, filePath, "Should record correct path")
        XCTAssertEqual(call.atomically, true, "Should record atomically flag")
        XCTAssertNil(call.options, "Should not have options for atomically variant")

        try assertFileContainsTestData()
    }

    func testWriteToFileOptionsError_whenSwizzled_shouldCallTracker() throws {
        // -- Arrange --
        swizzle()
        XCTAssertEqual(mockTracker.writeCalls.count, 0, "Should start with no write calls")

        // -- Act --
        try (testData as NSData).write(toFile: filePath, options: .atomic)

        // -- Assert --
        XCTAssertEqual(mockTracker.writeCalls.count, 1, "Should record one write call")

        let call = mockTracker.writeCalls[0]
        XCTAssertEqual(call.data, testData, "Should record correct data")
        XCTAssertEqual(call.path, filePath, "Should record correct path")
        XCTAssertNil(call.atomically, "Should not have atomically for options variant")
        XCTAssertEqual(call.options, .atomic, "Should record options")

        try assertFileContainsTestData()
    }

    func testWriteToFileOptionsError_whenWriteFails_shouldCallTracker() {
        // -- Arrange --
        swizzle()
        let invalidPath = "/invalid/path/that/does/not/exist/testfile.txt"
        XCTAssertEqual(mockTracker.writeCalls.count, 0, "Should start with no write calls")

        // -- Act --
        do {
            try (testData as NSData).write(toFile: invalidPath, options: .atomic)
            XCTFail("Write should have thrown an error")
        } catch {
            // Expected error
        }

        // -- Assert --
        // Should still call tracker even when the operation fails
        XCTAssertEqual(mockTracker.writeCalls.count, 1, "Should record write call even on failure")
        XCTAssertEqual(mockTracker.writeCalls[0].path, invalidPath, "Should record the invalid path")
    }

    // MARK: - Read Methods

    func testInitWithContentsOfFile_whenSwizzled_shouldCallTracker() throws {
        // -- Arrange --
        swizzle()
        try testData.write(to: fileUrl, options: .atomic)
        XCTAssertEqual(mockTracker.readCalls.count, 0, "Should start with no read calls")

        // -- Act --
        let readData = NSData(contentsOfFile: filePath)

        // -- Assert --
        XCTAssertNotNil(readData, "initWithContentsOfFile: should return data")
        XCTAssertEqual(readData as? Data, testData, "Read data should match written data")
        XCTAssertEqual(mockTracker.readCalls.count, 1, "Should record one read call")

        let call = mockTracker.readCalls[0]
        XCTAssertEqual(call.path, filePath, "Should record correct path")
        XCTAssertNil(call.url, "Should not have URL for file path variant")
        XCTAssertNil(call.options, "Should not have options for simple variant")
    }

    func testInitWithContentsOfFileOptionsError_whenSwizzled_shouldCallTracker() throws {
        // -- Arrange --
        swizzle()
        try testData.write(to: fileUrl, options: .atomic)
        XCTAssertEqual(mockTracker.readCalls.count, 0, "Should start with no read calls")

        // -- Act --
        let readData = try NSData(contentsOfFile: filePath, options: .uncached)

        // -- Assert --
        XCTAssertEqual(readData as Data, testData, "Read data should match written data")
        XCTAssertEqual(mockTracker.readCalls.count, 1, "Should record one read call")

        let call = mockTracker.readCalls[0]
        XCTAssertEqual(call.path, filePath, "Should record correct path")
        XCTAssertNil(call.url, "Should not have URL for file path variant")
        XCTAssertEqual(call.options, .uncached, "Should record options")
    }

    func testInitWithContentsOfFile_whenFileDoesNotExist_shouldCallTracker() {
        // -- Arrange --
        swizzle()
        let nonExistentPath = fileDirectory.appendingPathComponent("nonexistent_file.txt").path
        XCTAssertEqual(mockTracker.readCalls.count, 0, "Should start with no read calls")

        // -- Act --
        let readData = NSData(contentsOfFile: nonExistentPath)

        // -- Assert --
        XCTAssertNil(readData, "initWithContentsOfFile: should return nil for nonexistent file")
        // Should still call tracker even when the operation fails
        XCTAssertEqual(mockTracker.readCalls.count, 1, "Should record read call even on failure")
        XCTAssertEqual(mockTracker.readCalls[0].path, nonExistentPath, "Should record the nonexistent path")
    }

    func testInitWithContentsOfURL_whenSwizzled_shouldCallTracker() throws {
        // -- Arrange --
        swizzle()
        try testData.write(to: fileUrl, options: .atomic)
        XCTAssertEqual(mockTracker.readCalls.count, 0, "Should start with no read calls")

        // -- Act --
        let readData = NSData(contentsOf: fileUrl)

        // -- Assert --
        XCTAssertNotNil(readData, "initWithContentsOfURL: should return data")
        XCTAssertEqual(readData as? Data, testData, "Read data should match written data")
        XCTAssertEqual(mockTracker.readCalls.count, 1, "Should record one read call")

        let call = mockTracker.readCalls[0]
        // Note: NSData(contentsOf:) calls initWithContentsOfFile: with the file path, not the URL variant
        XCTAssertEqual(call.path, filePath, "Should record file path")
        XCTAssertNil(call.url, "Should not have URL for this variant")
        XCTAssertNil(call.options, "Should not have options for simple variant")
    }

    func testInitWithContentsOfURLOptionsError_whenSwizzled_shouldCallTracker() throws {
        // -- Arrange --
        swizzle()
        try testData.write(to: fileUrl, options: .atomic)
        XCTAssertEqual(mockTracker.readCalls.count, 0, "Should start with no read calls")

        // -- Act --
        let readData = try NSData(contentsOf: fileUrl, options: .uncached)

        // -- Assert --
        XCTAssertEqual(readData as Data, testData, "Read data should match written data")
        XCTAssertEqual(mockTracker.readCalls.count, 1, "Should record one read call")

        let call = mockTracker.readCalls[0]
        XCTAssertNil(call.path, "Should not have path for URL options variant")
        XCTAssertEqual(call.url, fileUrl, "Should record correct URL")
        XCTAssertEqual(call.options, .uncached, "Should record options")
    }

    // MARK: - Swizzling State Tests

    func testSwizzlingActive_whenSwizzled_shouldBeTrue() {
        // -- Arrange & Act --
        swizzle()

        // -- Assert --
        XCTAssertTrue(SentryNSDataSwizzlingHelper.swizzlingActive(), "Swizzling should be active after swizzle call")
    }

    func testSwizzlingActive_whenUnswizzled_shouldBeFalse() {
        // -- Arrange --
        swizzle()
        XCTAssertTrue(SentryNSDataSwizzlingHelper.swizzlingActive(), "Swizzling should initially be active")

        // -- Act --
        SentryNSDataSwizzlingHelper.unswizzle()

        // -- Assert --
        XCTAssertFalse(SentryNSDataSwizzlingHelper.swizzlingActive(), "Swizzling should be inactive after unswizzle")

        // Re-enable for proper tearDown
        SentryNSDataSwizzlingHelper.swizzle(withTracker: mockTracker as Any)
    }

    // MARK: - Unswizzle Tests

    func testUnswizzle_whenCalled_shouldStopTrackingCalls() throws {
        // -- Arrange --
        swizzle()
        XCTAssertEqual(mockTracker.writeCalls.count, 0, "Should start with no write calls")

        // Verify swizzling is working first
        _ = (testData as NSData).write(toFile: filePath, atomically: true)
        XCTAssertEqual(mockTracker.writeCalls.count, 1, "Should track call when swizzled")
        try FileManager.default.removeItem(at: fileUrl)

        // -- Act --
        SentryNSDataSwizzlingHelper.unswizzle()
        _ = (testData as NSData).write(toFile: filePath, atomically: true)

        // -- Assert --
        XCTAssertEqual(mockTracker.writeCalls.count, 1, "Should not track new calls after unswizzle")
        try assertFileContainsTestData()
    }

    func testUnswizzle_whenCalledMultipleTimes_shouldNotCrash() {
        // -- Arrange --
        swizzle()

        // -- Act & Assert --
        // Should not crash when unswizzling multiple times
        SentryNSDataSwizzlingHelper.unswizzle()
        SentryNSDataSwizzlingHelper.unswizzle()
        SentryNSDataSwizzlingHelper.unswizzle()
    }

    // MARK: - Multiple Operations

    func testMultipleOperations_whenSwizzled_shouldRecordAllCalls() {
        // -- Arrange --
        swizzle()
        XCTAssertEqual(mockTracker.writeCalls.count, 0, "Should start with no write calls")
        XCTAssertEqual(mockTracker.readCalls.count, 0, "Should start with no read calls")

        // -- Act --
        _ = (testData as NSData).write(toFile: filePath, atomically: true)
        let readData1 = NSData(contentsOfFile: filePath)
        let readData2 = NSData(contentsOf: fileUrl)

        // -- Assert --
        XCTAssertNotNil(readData1, "First read should succeed")
        XCTAssertNotNil(readData2, "Second read should succeed")

        XCTAssertEqual(mockTracker.writeCalls.count, 1, "Should record one write call")
        XCTAssertEqual(mockTracker.readCalls.count, 2, "Should record two read calls")

        // Verify write call
        XCTAssertEqual(mockTracker.writeCalls[0].path, filePath, "Write should be to correct path")

        // Verify read calls - both use file path variant
        XCTAssertEqual(mockTracker.readCalls[0].path, filePath, "First read should be from correct path")
        XCTAssertEqual(mockTracker.readCalls[1].path, filePath, "Second read should also be from file path")
    }

    // MARK: - Helper Methods

    private func assertFileContainsTestData() throws {
        let writtenData = try Data(contentsOf: fileUrl)
        XCTAssertEqual(writtenData, testData, "File should contain the test data")
    }
}

// MARK: - Mock Tracker

private class MockFileIOTracker: NSObject {
    struct WriteCall {
        let data: Data
        let path: String
        let atomically: Bool?
        let options: NSData.WritingOptions?
    }

    struct ReadCall {
        let path: String?
        let url: URL?
        let options: NSData.ReadingOptions?
    }

    var writeCalls: [WriteCall] = []
    var readCalls: [ReadCall] = []
    var shouldReturnData = true

    func enable() {
        // No-op for mock
    }

    func disable() {
        // No-op for mock
    }

    @objc func measureNSData(
        _ data: Data,
        writeToFile path: String,
        atomically: Bool,
        origin: String,
        method: @escaping (String, Bool) -> Bool
    ) -> Bool {
        writeCalls.append(WriteCall(data: data, path: path, atomically: atomically, options: nil))
        return method(path, atomically)
    }

    @objc func measureNSData(
        _ data: Data,
        writeToFile path: String,
        options writeOptionsMask: NSData.WritingOptions,
        origin: String,
        error: NSErrorPointer,
        method: @escaping (String, NSData.WritingOptions, NSErrorPointer) -> Bool
    ) -> Bool {
        writeCalls.append(WriteCall(data: data, path: path, atomically: nil, options: writeOptionsMask))
        return method(path, writeOptionsMask, error)
    }

    @objc func measureNSDataFromFile(
        _ path: String,
        origin: String,
        method: @escaping (String) -> NSData?
    ) -> NSData? {
        readCalls.append(ReadCall(path: path, url: nil, options: nil))
        return shouldReturnData ? method(path) : nil
    }

    @objc func measureNSDataFromFile(
        _ path: String,
        options readOptionsMask: NSData.ReadingOptions,
        origin: String,
        error: NSErrorPointer,
        method: @escaping (String, NSData.ReadingOptions, NSErrorPointer) -> NSData?
    ) -> NSData? {
        readCalls.append(ReadCall(path: path, url: nil, options: readOptionsMask))
        return shouldReturnData ? method(path, readOptionsMask, error) : nil
    }

    @objc func measureNSDataFromURL(
        _ url: URL,
        options readOptionsMask: NSData.ReadingOptions,
        origin: String,
        error: NSErrorPointer,
        method: @escaping (URL, NSData.ReadingOptions, NSErrorPointer) -> NSData?
    ) -> NSData? {
        readCalls.append(ReadCall(path: nil, url: url, options: readOptionsMask))
        return shouldReturnData ? method(url, readOptionsMask, error) : nil
    }
}
