@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

class SentryScopeContextPersistentStoreTests: XCTestCase {
    private static let dsn = TestConstants.dsnForTestCase(type: SentryScopeContextPersistentStoreTests.self)

    private class Fixture {
        let fileManager: TestFileManager

        init() throws {
            let options = Options()
            options.dsn = SentryScopeContextPersistentStoreTests.dsn
            fileManager = try TestFileManager(options: options)
        }

        func getSut() throws -> SentryScopeContextPersistentStore {
            return try XCTUnwrap(SentryScopeContextPersistentStore(fileManager: fileManager))
        }
    }

    private var fixture: Fixture!
    private var sut: SentryScopeContextPersistentStore!

    override func setUpWithError() throws {
        super.setUp()

        fixture = try Fixture()
        sut = try fixture.getSut()
    }

    func testMoveFileToPreviousFile_whenPreviousContextFileAvailable_shouldMoveFileToPreviousPath() throws {
        // -- Arrange --
        let fm = FileManager.default
        let data = Data("<TEST DATA>".utf8)

        if fm.fileExists(atPath: sut.previousContextFileURL.path) {
            try fm.removeItem(at: sut.previousContextFileURL)
        }
        if fm.fileExists(atPath: sut.contextFileURL.path) {
            try fm.removeItem(at: sut.contextFileURL)
        }
        fm.createFile(atPath: sut.contextFileURL.path, contents: data)

        XCTAssertTrue(fm.fileExists(atPath: sut.contextFileURL.path))
        XCTAssertFalse(fm.fileExists(atPath: sut.previousContextFileURL.path))

        // -- Act --
        sut.moveCurrentFileToPreviousFile()

        // -- Assert --
        XCTAssertFalse(fm.fileExists(atPath: sut.contextFileURL.path))
        XCTAssertTrue(fm.fileExists(atPath: sut.previousContextFileURL.path))

        let previousContextData = try Data(contentsOf: sut.previousContextFileURL)
        XCTAssertEqual(previousContextData, data)
    }

    func testReadPreviousContext_whenValidJSONInPreviousContextFile_shouldReturnDecodedData() throws {
        // -- Arrange --
        let fm = FileManager.default
        let data = Data("""
            {
                "key": {
                    "nestedKey": "value"
                },
                "anotherKey": {
                    "anotherNestedKey": "nestedValue"
                }
            }
            """.utf8)
        try data.write(to: sut.previousContextFileURL)
        XCTAssertTrue(fm.fileExists(atPath: sut.previousContextFileURL.path))

        // -- Act --
        let result = try XCTUnwrap(sut.readPreviousContextFromDisk())

        // -- Assert --
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result["key"] as? [String: String], ["nestedKey": "value"])
        XCTAssertEqual(result["anotherKey"] as? [String: String], ["anotherNestedKey": "nestedValue"])
    }

    func testReadPreviousContext_whenInvalidJSONInPreviousContextFile_shouldReturnNil() throws {
        // -- Arrange --
        let fm = FileManager.default
        let data = Data("""
            {
                "key": 123,
                "anotherKey": {
                    "anotherNestedKey": "nestedValue"
                }
            }
            """.utf8)
        try data.write(to: sut.previousContextFileURL)
        XCTAssertTrue(fm.fileExists(atPath: sut.previousContextFileURL.path))

        // -- Act --
        let result = sut.readPreviousContextFromDisk()

        // -- Assert --
        XCTAssertNil(result)
    }

    func testReadPreviousContext_whenInvalidDataInPreviousContextFile_shouldReturnNil() throws {
        // -- Arrange --
        let fm = FileManager.default
        let data = Data("<TEST DATA>".utf8)
        try data.write(to: sut.previousContextFileURL)
        XCTAssertTrue(fm.fileExists(atPath: sut.previousContextFileURL.path))

        // -- Act --
        let result = sut.readPreviousContextFromDisk()

        // -- Assert --
        XCTAssertNil(result)
    }

    func testReadPreviousContext_whenPreviousContextUnvailable_shouldReturnData() throws {
        // -- Arrange --
        // Check pre-conditions
        let fm = FileManager.default
        if fm.fileExists(atPath: sut.previousContextFileURL.path) {
            try fm.removeItem(at: sut.previousContextFileURL)
        }
        XCTAssertFalse(fm.fileExists(atPath: sut.previousContextFileURL.path))

        // -- Act --
        let result = sut.readPreviousContextFromDisk()

        // -- Assert --
        XCTAssertNil(result)
    }

    func testWriteContextToDisk_whenNestedDictionaryJSONData_shouldWriteToContextFile() throws {
        // -- Arrange --
        let fm = FileManager.default
        let context: [String: [String: Any]] = [
            "key": ["nestedKey": 123],
            "anotherKey": ["anotherNestedKey": "nestedValue"]
        ]

        // Check pre-conditions
        XCTAssertFalse(fm.fileExists(atPath: sut.contextFileURL.path))

        // -- Act --
        sut.writeContextToDisk(context: context)

        // -- Assert --
        XCTAssertTrue(fm.fileExists(atPath: sut.contextFileURL.path))
        // Use the SentrySerialization to compare the written data
        // We can assume the utility to serialize the context correctly as it is tested by other tests.
        let writtenData = try Data(contentsOf: sut.contextFileURL)
        let serializedData = try XCTUnwrap(SentrySerialization.deserializeDictionary(fromJsonData: writtenData))

        XCTAssertEqual(serializedData.count, 2)
        XCTAssertEqual(serializedData["key"] as? [String: Int], ["nestedKey": 123])
        XCTAssertEqual(serializedData["anotherKey"] as? [String: String], ["anotherNestedKey": "nestedValue"])
    }

    func testWriteContextToDisk_whenInvalidJSONDictionary_shouldNotWriteToContextFile() throws {
        // -- Arrange --
        let fm = FileManager.default
        let context: [String: [String: Any]] = [
            "key": ["nestedKey": Double.infinity],
            "anotherKey": ["anotherNestedKey": "nestedValue"]
        ]
        if fm.fileExists(atPath: sut.contextFileURL.path) {
            try fm.removeItem(at: sut.contextFileURL)
        }

        // Check pre-conditions
        XCTAssertFalse(fm.fileExists(atPath: sut.contextFileURL.path))

        // -- Act --
        sut.writeContextToDisk(context: context)

        // -- Assert --
        XCTAssertFalse(fm.fileExists(atPath: sut.contextFileURL.path))
    }

    func testWriteContextToDisk_whenNonLiteralsINJSONDictionary_shouldSanitizeAndWriteToContextFile() throws {
        // -- Arrange --
        let fm = FileManager.default
        let context: [String: [String: Any]] = [
            "key": ["nestedKey": Date(timeIntervalSince1970: 0xF00D)]
        ]
        if fm.fileExists(atPath: sut.contextFileURL.path) {
            try fm.removeItem(at: sut.contextFileURL)
        }

        // Check pre-conditions
        XCTAssertFalse(fm.fileExists(atPath: sut.contextFileURL.path))

        // -- Act --
        sut.writeContextToDisk(context: context)

        // -- Assert --
        // Use the SentrySerialization to compare the written data
        // We can assume the utility to serialize the context correctly as it is tested by other tests.
        let writtenData = try Data(contentsOf: sut.contextFileURL)
        let serializedData = try XCTUnwrap(SentrySerialization.deserializeDictionary(fromJsonData: writtenData))

        XCTAssertEqual(serializedData.count, 1)
        let nestedDict = try XCTUnwrap(serializedData["key"] as? [String: String])
        XCTAssertEqual(nestedDict["nestedKey"], "1970-01-01T17:04:13.000Z")
    }

    func testDeleteContextFile_whenExists_shouldDeleteFile() throws {
        // -- Arrange --
        let fm = FileManager.default
        if !fm.fileExists(atPath: sut.contextFileURL.path) {
            try "".write(to: sut.contextFileURL, atomically: true, encoding: .utf8)
        }
        XCTAssertTrue(fm.fileExists(atPath: sut.contextFileURL.path))

        // -- Act --
        sut.deleteContextOnDisk()

        // -- Assert --
        XCTAssertFalse(fm.fileExists(atPath: sut.contextFileURL.path))
    }

    func testDeleteContextFile_whenNotExists_shouldDoNothing() throws {
        // -- Arrange --
        let fm = FileManager.default
        if fm.fileExists(atPath: sut.contextFileURL.path) {
           try fm.removeItem(at: sut.contextFileURL)
        }
        XCTAssertFalse(fm.fileExists(atPath: sut.contextFileURL.path))

        // -- Act --
        sut.deleteContextOnDisk()

        // -- Assert --
        XCTAssertFalse(fm.fileExists(atPath: sut.contextFileURL.path))
    }

    func testContextFileURL_returnsURLWithCorrectPath() {
        // -- Arrange --
        let expectedUrl = URL(fileURLWithPath: fixture.fileManager.sentryPath)
            .appendingPathComponent("context.state")

        // -- Act && Assert --
        XCTAssertEqual(sut.contextFileURL, expectedUrl)
    }

    func testPreviousContextFileURL_returnsURLWithCorrectPath() {
        // -- Arrange --
        let expectedUrl = URL(fileURLWithPath: fixture.fileManager.sentryPath)
            .appendingPathComponent("previous.context.state")

        // -- Act && Assert --
        XCTAssertEqual(sut.previousContextFileURL, expectedUrl)
    }
}
