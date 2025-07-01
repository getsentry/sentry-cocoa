@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

class SentryScopeTagsPersistentStoreTests: XCTestCase {
    private static let dsn = TestConstants.dsnForTestCase(type: SentryScopeTagsPersistentStoreTests.self)

    private class Fixture {
        let fileManager: TestFileManager

        init() throws {
            let options = Options()
            options.dsn = SentryScopeTagsPersistentStoreTests.dsn
            fileManager = try TestFileManager(options: options)
        }

        func getSut() -> SentryScopeTagsPersistentStore {
            return SentryScopeTagsPersistentStore(fileManager: fileManager)
        }
    }

    private var fixture: Fixture!
    private var sut: SentryScopeTagsPersistentStore!

    override func setUpWithError() throws {
        super.setUp()

        fixture = try Fixture()
        sut = fixture.getSut()
    }

    func testMoveFileToPreviousFile_whenPreviousTagsFileAvailable_shouldMoveFileToPreviousPath() throws {
        // -- Arrange --
        let fm = FileManager.default
        let data = Data("""
            {
                "environment": "production",
                "version": "1.0.0"
            }
            """.utf8)

        if fm.fileExists(atPath: sut.previousFileURL.path) {
            try fm.removeItem(at: sut.previousFileURL)
        }
        if fm.fileExists(atPath: sut.currentFileURL.path) {
            try fm.removeItem(at: sut.currentFileURL)
        }
        fm.createFile(atPath: sut.currentFileURL.path, contents: data)

        XCTAssertTrue(fm.fileExists(atPath: sut.currentFileURL.path))
        XCTAssertFalse(fm.fileExists(atPath: sut.previousFileURL.path))

        // -- Act --
        sut.moveCurrentFileToPreviousFile()

        // -- Assert --
        XCTAssertFalse(fm.fileExists(atPath: sut.currentFileURL.path))
        XCTAssertTrue(fm.fileExists(atPath: sut.previousFileURL.path))

        let previousTagsData = try Data(contentsOf: sut.previousFileURL)
        XCTAssertEqual(previousTagsData, data)
    }

    func testReadPreviousTags_whenValidJSONInPreviousTagsFile_shouldReturnDecodedTags() throws {
        // -- Arrange --
        let fm = FileManager.default
        let data = Data("""
            {
                "environment": "production",
                "version": "1.0.0",
                "user_type": "premium"
            }
            """.utf8)
        try data.write(to: sut.previousFileURL)
        XCTAssertTrue(fm.fileExists(atPath: sut.previousFileURL.path))

        // -- Act --
        let result = try XCTUnwrap(sut.readPreviousTagsFromDisk())

        // -- Assert --
        XCTAssertEqual(result["environment"], "production")
        XCTAssertEqual(result["version"], "1.0.0")
        XCTAssertEqual(result["user_type"], "premium")
        XCTAssertEqual(result.count, 3)
    }

    func testReadPreviousTags_whenInvalidJSONInPreviousTagsFile_shouldReturnNil() throws {
        // -- Arrange --
        let fm = FileManager.default
        let data = Data("""
            {
                "environment": "production",
                "version": 1.0,
            """.utf8)
        try data.write(to: sut.previousFileURL)
        XCTAssertTrue(fm.fileExists(atPath: sut.previousFileURL.path))

        // -- Act --
        let result = sut.readPreviousTagsFromDisk()

        // -- Assert --
        XCTAssertNil(result)
    }

    func testReadPreviousTags_whenInvalidDataInPreviousTagsFile_shouldReturnNil() throws {
        // -- Arrange --
        let fm = FileManager.default
        let data = Data("<TEST DATA>".utf8)
        try data.write(to: sut.previousFileURL)
        XCTAssertTrue(fm.fileExists(atPath: sut.previousFileURL.path))

        // -- Act --
        let result = sut.readPreviousTagsFromDisk()

        // -- Assert --
        XCTAssertNil(result)
    }

    func testReadPreviousTags_whenPreviousTagsUnavailable_shouldReturnNil() throws {
        // -- Arrange --
        // Check pre-conditions
        let fm = FileManager.default
        if fm.fileExists(atPath: sut.previousFileURL.path) {
            try fm.removeItem(at: sut.previousFileURL)
        }
        XCTAssertFalse(fm.fileExists(atPath: sut.previousFileURL.path))

        // -- Act --
        let result = sut.readPreviousTagsFromDisk()

        // -- Assert --
        XCTAssertNil(result)
    }

    func testWriteTagsToDisk_whenValidTagsData_shouldWriteToTagsFile() throws {
        // -- Arrange --
        let fm = FileManager.default
        let tags: [String: String] = [
            "environment": "production",
            "version": "1.0.0",
            "user_type": "premium"
        ]

        // Check pre-conditions
        if fm.fileExists(atPath: sut.currentFileURL.path) {
            try fm.removeItem(at: sut.currentFileURL)
        }
        XCTAssertFalse(fm.fileExists(atPath: sut.currentFileURL.path))

        // -- Act --
        sut.writeTagsToDisk(tags: tags)

        // -- Assert --
        XCTAssertTrue(fm.fileExists(atPath: sut.currentFileURL.path))
        let writtenData = try Data(contentsOf: sut.currentFileURL)
        let serializedData = try XCTUnwrap(SentrySerialization.deserializeDictionary(fromJsonData: writtenData))

        XCTAssertEqual(serializedData["environment"] as? String, "production")
        XCTAssertEqual(serializedData["version"] as? String, "1.0.0")
        XCTAssertEqual(serializedData["user_type"] as? String, "premium")
    }

    func testWriteTagsToDisk_whenEmptyTags_shouldWriteToTagsFile() throws {
        // -- Arrange --
        let fm = FileManager.default
        let tags: [String: String] = [:]

        // Check pre-conditions
        if fm.fileExists(atPath: sut.currentFileURL.path) {
            try fm.removeItem(at: sut.currentFileURL)
        }
        XCTAssertFalse(fm.fileExists(atPath: sut.currentFileURL.path))

        // -- Act --
        sut.writeTagsToDisk(tags: tags)

        // -- Assert --
        XCTAssertTrue(fm.fileExists(atPath: sut.currentFileURL.path))
        let writtenData = try Data(contentsOf: sut.currentFileURL)
        let serializedData = try XCTUnwrap(SentrySerialization.deserializeDictionary(fromJsonData: writtenData))
        XCTAssertTrue(serializedData.isEmpty)
    }

    func testDeleteTagsFile_whenExists_shouldDeleteFile() throws {
        // -- Arrange --
        let fm = FileManager.default
        if !fm.fileExists(atPath: sut.currentFileURL.path) {
            let tagsData = try JSONSerialization.data(withJSONObject: ["test": "value"])
            try tagsData.write(to: sut.currentFileURL)
        }
        XCTAssertTrue(fm.fileExists(atPath: sut.currentFileURL.path))

        // -- Act --
        sut.deleteStateOnDisk()

        // -- Assert --
        XCTAssertFalse(fm.fileExists(atPath: sut.currentFileURL.path))
    }

    func testDeleteTagsFile_whenNotExists_shouldDoNothing() throws {
        // -- Arrange --
        let fm = FileManager.default
        if fm.fileExists(atPath: sut.currentFileURL.path) {
           try fm.removeItem(at: sut.currentFileURL)
        }
        XCTAssertFalse(fm.fileExists(atPath: sut.currentFileURL.path))

        // -- Act --
        sut.deleteStateOnDisk()

        // -- Assert --
        XCTAssertFalse(fm.fileExists(atPath: sut.currentFileURL.path))
    }

    func testDeletePreviousTagsFile_whenExists_shouldDeleteFile() throws {
        // -- Arrange --
        let fm = FileManager.default
        if !fm.fileExists(atPath: sut.previousFileURL.path) {
            let tagsData = try JSONSerialization.data(withJSONObject: ["test": "value"])
            try tagsData.write(to: sut.previousFileURL)
        }
        XCTAssertTrue(fm.fileExists(atPath: sut.previousFileURL.path))

        // -- Act --
        sut.deletePreviousStateOnDisk()

        // -- Assert --
        XCTAssertFalse(fm.fileExists(atPath: sut.previousFileURL.path))
    }

    func testDeletePreviousTagsFile_whenNotExists_shouldDoNothing() throws {
        // -- Arrange --
        let fm = FileManager.default
        if fm.fileExists(atPath: sut.previousFileURL.path) {
           try fm.removeItem(at: sut.previousFileURL)
        }
        XCTAssertFalse(fm.fileExists(atPath: sut.previousFileURL.path))

        // -- Act --
        sut.deletePreviousStateOnDisk()

        // -- Assert --
        XCTAssertFalse(fm.fileExists(atPath: sut.previousFileURL.path))
    }

    func testCurrentFileURL_returnsURLWithCorrectPath() {
        // -- Arrange --
        let expectedUrl = URL(fileURLWithPath: fixture.fileManager.sentryPath)
            .appendingPathComponent("tags.state")

        // -- Act && Assert --
        XCTAssertEqual(sut.currentFileURL, expectedUrl)
    }

    func testPreviousFileURL_returnsURLWithCorrectPath() {
        // -- Arrange --
        let expectedUrl = URL(fileURLWithPath: fixture.fileManager.sentryPath)
            .appendingPathComponent("previous.tags.state")

        // -- Act && Assert --
        XCTAssertEqual(sut.previousFileURL, expectedUrl)
    }
}
