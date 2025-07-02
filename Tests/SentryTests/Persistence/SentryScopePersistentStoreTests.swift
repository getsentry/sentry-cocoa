@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

class SentryScopePersistentStoreTests: XCTestCase {
    private static let dsn = TestConstants.dsnForTestCase(type: SentryScopePersistentStore.self)

    private class Fixture {
        let fileManager: TestFileManager

        init() throws {
            let options = Options()
            options.dsn = SentryScopePersistentStoreTests.dsn
            fileManager = try TestFileManager(options: options)
        }

        func getSut() throws -> SentryScopePersistentStore {
            return try XCTUnwrap(SentryScopePersistentStore(fileManager: fileManager))
        }
    }

    private var fixture: Fixture!
    private var sut: SentryScopePersistentStore!

    override func setUpWithError() throws {
        super.setUp()

        fixture = try Fixture()
        sut = try fixture.getSut()
    }

    func testMoveAllCurrentStateToPreviousState_whenPreviousContextFileAvailable_shouldMoveFileToPreviousPath() throws {
        // -- Arrange --
        let fm = FileManager.default
        let data = Data("<TEST DATA>".utf8)
        let contextFileURL = sut.currentFileURLFor(field: .context)
        let previousContextFileURL = sut.previousFileURLFor(field: .context)

        if fm.fileExists(atPath: previousContextFileURL.path) {
            try fm.removeItem(at: previousContextFileURL)
        }
        if fm.fileExists(atPath: contextFileURL.path) {
            try fm.removeItem(at: contextFileURL)
        }
        fm.createFile(atPath: contextFileURL.path, contents: data)

        XCTAssertTrue(fm.fileExists(atPath: contextFileURL.path))
        XCTAssertFalse(fm.fileExists(atPath: previousContextFileURL.path))

        // -- Act --
        sut.moveAllCurrentStateToPreviousState()

        // -- Assert --
        XCTAssertFalse(fm.fileExists(atPath: contextFileURL.path))
        XCTAssertTrue(fm.fileExists(atPath: previousContextFileURL.path))

        let previousContextData = try Data(contentsOf: previousContextFileURL)
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
        let previousContextFileURL = sut.previousFileURLFor(field: .context)
        try data.write(to: previousContextFileURL)
        XCTAssertTrue(fm.fileExists(atPath: previousContextFileURL.path))

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
        let previousContextFileURL = sut.previousFileURLFor(field: .context)
        try data.write(to: previousContextFileURL)
        XCTAssertTrue(fm.fileExists(atPath: previousContextFileURL.path))

        // -- Act --
        let result = sut.readPreviousContextFromDisk()

        // -- Assert --
        XCTAssertNil(result)
    }

    func testReadPreviousContext_whenInvalidDataInPreviousContextFile_shouldReturnNil() throws {
        // -- Arrange --
        let fm = FileManager.default
        let data = Data("<TEST DATA>".utf8)
        let previousContextFileURL = sut.previousFileURLFor(field: .context)
        try data.write(to: previousContextFileURL)
        XCTAssertTrue(fm.fileExists(atPath: previousContextFileURL.path))

        // -- Act --
        let result = sut.readPreviousContextFromDisk()

        // -- Assert --
        XCTAssertNil(result)
    }

    func testReadPreviousContext_whenPreviousContextUnavailable_shouldReturnNil() throws {
        // -- Arrange --
        // Check pre-conditions
        let fm = FileManager.default
        let previousContextFileURL = sut.previousFileURLFor(field: .context)
        if fm.fileExists(atPath: previousContextFileURL.path) {
            try fm.removeItem(at: previousContextFileURL)
        }
        XCTAssertFalse(fm.fileExists(atPath: previousContextFileURL.path))

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
        let contextFileURL = sut.currentFileURLFor(field: .context)

        // Check pre-conditions
        XCTAssertFalse(fm.fileExists(atPath: contextFileURL.path))

        // -- Act --
        sut.writeContextToDisk(context: context)

        // -- Assert --
        XCTAssertTrue(fm.fileExists(atPath: contextFileURL.path))
        // Use the SentrySerialization to compare the written data
        // We can assume the utility to serialize the context correctly as it is tested by other tests.
        let writtenData = try Data(contentsOf: contextFileURL)
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
        let contextFileURL = sut.currentFileURLFor(field: .context)
        if fm.fileExists(atPath: contextFileURL.path) {
            try fm.removeItem(at: contextFileURL)
        }

        // Check pre-conditions
        XCTAssertFalse(fm.fileExists(atPath: contextFileURL.path))

        // -- Act --
        sut.writeContextToDisk(context: context)

        // -- Assert --
        XCTAssertFalse(fm.fileExists(atPath: contextFileURL.path))
    }

    func testWriteContextToDisk_whenNonLiteralsInJSONDictionary_shouldSanitizeAndWriteToContextFile() throws {
        // -- Arrange --
        let fm = FileManager.default
        let context: [String: [String: Any]] = [
            "key": ["nestedKey": Date(timeIntervalSince1970: 0xF00D)]
        ]
        let contextFileURL = sut.currentFileURLFor(field: .context)
        if fm.fileExists(atPath: contextFileURL.path) {
            try fm.removeItem(at: contextFileURL)
        }

        // Check pre-conditions
        XCTAssertFalse(fm.fileExists(atPath: contextFileURL.path))

        // -- Act --
        sut.writeContextToDisk(context: context)

        // -- Assert --
        // Use the SentrySerialization to compare the written data
        // We can assume the utility to serialize the context correctly as it is tested by other tests.
        let writtenData = try Data(contentsOf: contextFileURL)
        let serializedData = try XCTUnwrap(SentrySerialization.deserializeDictionary(fromJsonData: writtenData))

        XCTAssertEqual(serializedData.count, 1)
        let nestedDict = try XCTUnwrap(serializedData["key"] as? [String: String])
        XCTAssertEqual(nestedDict["nestedKey"], "1970-01-01T17:04:13.000Z")
    }

    func testDeleteCurrentFieldOnDisk_whenExists_shouldDeleteFile() throws {
        // -- Arrange --
        let fm = FileManager.default
        let contextFileURL = sut.currentFileURLFor(field: .context)
        if !fm.fileExists(atPath: contextFileURL.path) {
            try "".write(to: contextFileURL, atomically: true, encoding: .utf8)
        }
        XCTAssertTrue(fm.fileExists(atPath: contextFileURL.path))

        // -- Act --
        sut.deleteCurrentFieldOnDisk(field: .context)

        // -- Assert --
        XCTAssertFalse(fm.fileExists(atPath: contextFileURL.path))
    }

    func testDeleteCurrentFieldOnDisk_whenNotExists_shouldDoNothing() throws {
        // -- Arrange --
        let fm = FileManager.default
        let contextFileURL = sut.currentFileURLFor(field: .context)
        if fm.fileExists(atPath: contextFileURL.path) {
           try fm.removeItem(at: contextFileURL)
        }
        XCTAssertFalse(fm.fileExists(atPath: contextFileURL.path))

        // -- Act --
        sut.deleteCurrentFieldOnDisk(field: .context)

        // -- Assert --
        XCTAssertFalse(fm.fileExists(atPath: contextFileURL.path))
    }

    func testCurrentFileURLFor_returnsURLWithCorrectPath() {
        // -- Arrange --
        let expectedUrl = URL(fileURLWithPath: fixture.fileManager.sentryPath)
            .appendingPathComponent("context.state")

        // -- Act && Assert --
        XCTAssertEqual(sut.currentFileURLFor(field: .context), expectedUrl)
    }

    func testPreviousFileURLFor_returnsURLWithCorrectPath() {
        // -- Arrange --
        let expectedUrl = URL(fileURLWithPath: fixture.fileManager.sentryPath)
            .appendingPathComponent("previous.context.state")

        // -- Act && Assert --
        XCTAssertEqual(sut.previousFileURLFor(field: .context), expectedUrl)
    }

    func testReadPreviousUserFromDisk_whenValidJSONInPreviousUserFile_shouldReturnDecodedUser() throws {
        // -- Arrange --
        let fm = FileManager.default
        let user = User(userId: "test-user")
        user.email = "test@example.com"
        user.username = "testuser"
        
        let userData = try XCTUnwrap(SentrySerialization.data(withJSONObject: user.serialize()))
        let previousUserFileURL = sut.previousFileURLFor(field: .user)
        try userData.write(to: previousUserFileURL)
        XCTAssertTrue(fm.fileExists(atPath: previousUserFileURL.path))

        // -- Act --
        let result = try XCTUnwrap(sut.readPreviousUserFromDisk())

        // -- Assert --
        XCTAssertEqual(result.userId, "test-user")
        XCTAssertEqual(result.email, "test@example.com")
        XCTAssertEqual(result.username, "testuser")
    }

    func testWriteUserToDisk_whenValidUser_shouldWriteToUserFile() throws {
        // -- Arrange --
        let fm = FileManager.default
        let user = User(userId: "test-user")
        user.email = "test@example.com"
        user.username = "testuser"
        
        let userFileURL = sut.currentFileURLFor(field: .user)

        // Check pre-conditions
        XCTAssertFalse(fm.fileExists(atPath: userFileURL.path))

        // -- Act --
        sut.writeUserToDisk(user: user)

        // -- Assert --
        XCTAssertTrue(fm.fileExists(atPath: userFileURL.path))
        
        let writtenData = try Data(contentsOf: userFileURL)
        let decodedUser = try JSONDecoder().decode(User.self, from: writtenData)
        
        XCTAssertEqual(decodedUser.userId, "test-user")
        XCTAssertEqual(decodedUser.email, "test@example.com")
        XCTAssertEqual(decodedUser.username, "testuser")
    }

    func testDeleteAllCurrentState_shouldDeleteAllCurrentFiles() throws {
        // -- Arrange --
        let fm = FileManager.default
        let contextFileURL = sut.currentFileURLFor(field: .context)
        let userFileURL = sut.currentFileURLFor(field: .user)
        
        // Create test files
        try "context data".write(to: contextFileURL, atomically: true, encoding: .utf8)
        try "user data".write(to: userFileURL, atomically: true, encoding: .utf8)
        
        XCTAssertTrue(fm.fileExists(atPath: contextFileURL.path))
        XCTAssertTrue(fm.fileExists(atPath: userFileURL.path))

        // -- Act --
        sut.deleteAllCurrentState()

        // -- Assert --
        XCTAssertFalse(fm.fileExists(atPath: contextFileURL.path))
        XCTAssertFalse(fm.fileExists(atPath: userFileURL.path))
    }

    func testDeleteAllPreviousState_shouldDeleteAllPreviousFiles() throws {
        // -- Arrange --
        let fm = FileManager.default
        let previousContextFileURL = sut.previousFileURLFor(field: .context)
        let previousUserFileURL = sut.previousFileURLFor(field: .user)
        
        // Create test files
        try "previous context data".write(to: previousContextFileURL, atomically: true, encoding: .utf8)
        try "previous user data".write(to: previousUserFileURL, atomically: true, encoding: .utf8)
        
        XCTAssertTrue(fm.fileExists(atPath: previousContextFileURL.path))
        XCTAssertTrue(fm.fileExists(atPath: previousUserFileURL.path))

        // -- Act --
        sut.deleteAllPreviousState()

        // -- Assert --
        XCTAssertFalse(fm.fileExists(atPath: previousContextFileURL.path))
        XCTAssertFalse(fm.fileExists(atPath: previousUserFileURL.path))
    }
}
