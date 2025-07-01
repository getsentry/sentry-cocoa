@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

class SentryScopeLevelPersistentStoreTests: XCTestCase {
    private static let dsn = TestConstants.dsnForTestCase(type: SentryScopeLevelPersistentStoreTests.self)

    private class Fixture {
        let fileManager: TestFileManager

        init() throws {
            let options = Options()
            options.dsn = SentryScopeLevelPersistentStoreTests.dsn
            fileManager = try TestFileManager(options: options)
        }

        func getSut() -> SentryScopeLevelPersistentStore {
            return SentryScopeLevelPersistentStore(fileManager: fileManager)
        }
    }

    private var fixture: Fixture!
    private var sut: SentryScopeLevelPersistentStore!

    override func setUpWithError() throws {
        super.setUp()

        fixture = try Fixture()
        sut = fixture.getSut()
    }

    func testMoveFileToPreviousFile_whenPreviousLevelFileAvailable_shouldMoveFileToPreviousPath() throws {
        // -- Arrange --
        let fm = FileManager.default
        let data = Data("debug".utf8)

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

        let previousLevelData = try Data(contentsOf: sut.previousFileURL)
        XCTAssertEqual(previousLevelData, data)
    }

    func testReadPreviousLevel_whenValidLevelInPreviousLevelFile_shouldReturnDecodedLevel() throws {
        // -- Arrange --
        let fm = FileManager.default
        let data = Data("error".utf8)
        try data.write(to: sut.previousFileURL)
        XCTAssertTrue(fm.fileExists(atPath: sut.previousFileURL.path))

        // -- Act --
        let result = sut.readPreviousLevelFromDisk()

        // -- Assert --
        XCTAssertEqual(result, .error)
    }

    func testReadPreviousLevel_whenInvalidLevelInPreviousLevelFile_shouldReturnError() throws {
        // -- Arrange --
        let fm = FileManager.default
        let data = Data("invalid_level".utf8)
        try data.write(to: sut.previousFileURL)
        XCTAssertTrue(fm.fileExists(atPath: sut.previousFileURL.path))

        // -- Act --
        let result = sut.readPreviousLevelFromDisk()

        // -- Assert --
        XCTAssertEqual(result, .error)
    }

    func testReadPreviousLevel_whenInvalidDataInPreviousLevelFile_shouldReturnError() throws {
        // -- Arrange --
        let fm = FileManager.default
        let data = Data("<TEST DATA>".utf8)
        try data.write(to: sut.previousFileURL)
        XCTAssertTrue(fm.fileExists(atPath: sut.previousFileURL.path))

        // -- Act --
        let result = sut.readPreviousLevelFromDisk()

        // -- Assert --
        XCTAssertEqual(result, .error)
    }

    func testReadPreviousLevel_whenPreviousLevelUnavailable_shouldReturnError() throws {
        // -- Arrange --
        // Check pre-conditions
        let fm = FileManager.default
        if fm.fileExists(atPath: sut.previousFileURL.path) {
            try fm.removeItem(at: sut.previousFileURL)
        }
        XCTAssertFalse(fm.fileExists(atPath: sut.previousFileURL.path))

        // -- Act --
        let result = sut.readPreviousLevelFromDisk()

        // -- Assert --
        XCTAssertEqual(result, .error)
    }

    func testWriteLevelToDisk_whenValidLevelData_shouldWriteToLevelFile() throws {
        // -- Arrange --
        let fm = FileManager.default
        let level: SentryLevel = .warning

        // Check pre-conditions
        if fm.fileExists(atPath: sut.currentFileURL.path) {
            try fm.removeItem(at: sut.currentFileURL)
        }
        XCTAssertFalse(fm.fileExists(atPath: sut.currentFileURL.path))

        // -- Act --
        sut.writeLevelToDisk(level: level)

        // -- Assert --
        XCTAssertTrue(fm.fileExists(atPath: sut.currentFileURL.path))
        let writtenData = try Data(contentsOf: sut.currentFileURL)
        let writtenString = String(data: writtenData, encoding: .utf8)
        XCTAssertEqual(writtenString, "warning")
    }

    func testWriteLevelToDisk_whenAllLevelTypes_shouldWriteCorrectStrings() throws {
        // -- Arrange --
        let fm = FileManager.default
        let testCases: [(SentryLevel, String)] = [
            (.none, "none"),
            (.debug, "debug"),
            (.info, "info"),
            (.warning, "warning"),
            (.error, "error"),
            (.fatal, "fatal")
        ]

        for (level, expectedString) in testCases {
            // Clean up previous test
            if fm.fileExists(atPath: sut.currentFileURL.path) {
                try fm.removeItem(at: sut.currentFileURL)
            }

            // -- Act --
            sut.writeLevelToDisk(level: level)

            // -- Assert --
            XCTAssertTrue(fm.fileExists(atPath: sut.currentFileURL.path))
            let writtenData = try Data(contentsOf: sut.currentFileURL)
            let writtenString = String(data: writtenData, encoding: .utf8)
            XCTAssertEqual(writtenString, expectedString, "Failed for level: \(level)")
        }
    }

    func testDeleteLevelFile_whenExists_shouldDeleteFile() throws {
        // -- Arrange --
        let fm = FileManager.default
        if !fm.fileExists(atPath: sut.currentFileURL.path) {
            try "debug".write(to: sut.currentFileURL, atomically: true, encoding: .utf8)
        }
        XCTAssertTrue(fm.fileExists(atPath: sut.currentFileURL.path))

        // -- Act --
        sut.deleteLevelOnDisk()

        // -- Assert --
        XCTAssertFalse(fm.fileExists(atPath: sut.currentFileURL.path))
    }

    func testDeleteLevelFile_whenNotExists_shouldDoNothing() throws {
        // -- Arrange --
        let fm = FileManager.default
        if fm.fileExists(atPath: sut.currentFileURL.path) {
           try fm.removeItem(at: sut.currentFileURL)
        }
        XCTAssertFalse(fm.fileExists(atPath: sut.currentFileURL.path))

        // -- Act --
        sut.deleteLevelOnDisk()

        // -- Assert --
        XCTAssertFalse(fm.fileExists(atPath: sut.currentFileURL.path))
    }

    func testDeletePreviousLevelFile_whenExists_shouldDeleteFile() throws {
        // -- Arrange --
        let fm = FileManager.default
        if !fm.fileExists(atPath: sut.previousFileURL.path) {
            try "error".write(to: sut.previousFileURL, atomically: true, encoding: .utf8)
        }
        XCTAssertTrue(fm.fileExists(atPath: sut.previousFileURL.path))

        // -- Act --
        sut.deletePreviousLevelOnDisk()

        // -- Assert --
        XCTAssertFalse(fm.fileExists(atPath: sut.previousFileURL.path))
    }

    func testDeletePreviousLevelFile_whenNotExists_shouldDoNothing() throws {
        // -- Arrange --
        let fm = FileManager.default
        if fm.fileExists(atPath: sut.previousFileURL.path) {
           try fm.removeItem(at: sut.previousFileURL)
        }
        XCTAssertFalse(fm.fileExists(atPath: sut.previousFileURL.path))

        // -- Act --
        sut.deletePreviousLevelOnDisk()

        // -- Assert --
        XCTAssertFalse(fm.fileExists(atPath: sut.previousFileURL.path))
    }

    func testCurrentFileURL_returnsURLWithCorrectPath() {
        // -- Arrange --
        let expectedUrl = URL(fileURLWithPath: fixture.fileManager.sentryPath)
            .appendingPathComponent("level.state")

        // -- Act && Assert --
        XCTAssertEqual(sut.currentFileURL, expectedUrl)
    }

    func testPreviousFileURL_returnsURLWithCorrectPath() {
        // -- Arrange --
        let expectedUrl = URL(fileURLWithPath: fixture.fileManager.sentryPath)
            .appendingPathComponent("previous.level.state")

        // -- Act && Assert --
        XCTAssertEqual(sut.previousFileURL, expectedUrl)
    }
}
