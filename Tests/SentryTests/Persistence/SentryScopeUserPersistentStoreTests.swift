@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

class SentryScopeUserPersistentStoreTests: XCTestCase {
    private static let dsn = TestConstants.dsnForTestCase(type: SentryScopeUserPersistentStoreTests.self)

    private class Fixture {
        let fileManager: TestFileManager

        init() throws {
            let options = Options()
            options.dsn = SentryScopeUserPersistentStoreTests.dsn
            fileManager = try TestFileManager(options: options)
        }

        func getSut() -> SentryScopeUserPersistentStore {
            return SentryScopeUserPersistentStore(fileManager: fileManager)
        }
    }

    private var fixture: Fixture!
    private var sut: SentryScopeUserPersistentStore!

    override func setUpWithError() throws {
        super.setUp()

        fixture = try Fixture()
        sut = fixture.getSut()
    }

    func testMoveFileToPreviousFile_whenPreviousUserFileAvailable_shouldMoveFileToPreviousPath() throws {
        // -- Arrange --
        let fm = FileManager.default
        let data = Data("<TEST DATA>".utf8)

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

        let previousUserData = try Data(contentsOf: sut.previousFileURL)
        XCTAssertEqual(previousUserData, data)
    }

    func testReadPreviousUser_whenValidJSONInPreviousUserFile_shouldReturnDecodedData() throws {
        // -- Arrange --
        let fm = FileManager.default
        let data = Data("""
            {
                "id": "user123",
                "email": "test@example.com",
                "username": "testuser",
                "ip_address": "192.168.1.1"
            }
            """.utf8)
        try data.write(to: sut.previousFileURL)
        XCTAssertTrue(fm.fileExists(atPath: sut.previousFileURL.path))

        // -- Act --
        let result = try XCTUnwrap(sut.readPreviousUserFromDisk())

        // -- Assert --
        XCTAssertEqual(result.userId, "user123")
        XCTAssertEqual(result.email, "test@example.com")
        XCTAssertEqual(result.username, "testuser")
        XCTAssertEqual(result.ipAddress, "192.168.1.1")
    }

    func testReadPreviousUser_whenInvalidJSONInPreviousUserFile_shouldReturnNil() throws {
        // -- Arrange --
        let fm = FileManager.default
        let data = Data("""
            {
                "id": 123,
            """.utf8)
        try data.write(to: sut.previousFileURL)
        XCTAssertTrue(fm.fileExists(atPath: sut.previousFileURL.path))

        // -- Act --
        let result = sut.readPreviousUserFromDisk()

        // -- Assert --
        XCTAssertNil(result)
    }

    func testReadPreviousUser_whenInvalidDataInPreviousUserFile_shouldReturnNil() throws {
        // -- Arrange --
        let fm = FileManager.default
        let data = Data("<TEST DATA>".utf8)
        try data.write(to: sut.previousFileURL)
        XCTAssertTrue(fm.fileExists(atPath: sut.previousFileURL.path))

        // -- Act --
        let result = sut.readPreviousUserFromDisk()

        // -- Assert --
        XCTAssertNil(result)
    }

    func testReadPreviousUser_whenPreviousUserUnavailable_shouldReturnNil() throws {
        // -- Arrange --
        // Check pre-conditions
        let fm = FileManager.default
        if fm.fileExists(atPath: sut.previousFileURL.path) {
            try fm.removeItem(at: sut.previousFileURL)
        }
        XCTAssertFalse(fm.fileExists(atPath: sut.previousFileURL.path))

        // -- Act --
        let result = sut.readPreviousUserFromDisk()

        // -- Assert --
        XCTAssertNil(result)
    }

    func testWriteUserToDisk_whenValidUserData_shouldWriteToUserFile() throws {
        // -- Arrange --
        let fm = FileManager.default
        let user = User(userId: "user123")
        user.email = "test@example.com"
        user.username = "testuser"
        user.ipAddress = "192.168.1.1"

        // Check pre-conditions
        XCTAssertFalse(fm.fileExists(atPath: sut.currentFileURL.path))

        // -- Act --
        sut.writeUserToDisk(user: user)

        // -- Assert --
        XCTAssertTrue(fm.fileExists(atPath: sut.currentFileURL.path))
        // Use the SentrySerialization to compare the written data
        let writtenData = try Data(contentsOf: sut.currentFileURL)
        let serializedData = try XCTUnwrap(SentrySerialization.deserializeDictionary(fromJsonData: writtenData))

        XCTAssertEqual(serializedData["id"] as? String, "user123")
        XCTAssertEqual(serializedData["email"] as? String, "test@example.com")
        XCTAssertEqual(serializedData["username"] as? String, "testuser")
        XCTAssertEqual(serializedData["ip_address"] as? String, "192.168.1.1")
    }

    func testWriteUserToDisk_whenInvalidUserData_shouldNotWriteToUserFile() throws {
        // -- Arrange --
        let fm = FileManager.default
        let user = User(userId: "user123")
        // Set an invalid value that can't be serialized
        user.data = ["invalid": Double.infinity]

        if fm.fileExists(atPath: sut.currentFileURL.path) {
            try fm.removeItem(at: sut.currentFileURL)
        }

        // Check pre-conditions
        XCTAssertFalse(fm.fileExists(atPath: sut.currentFileURL.path))

        // -- Act --
        sut.writeUserToDisk(user: user)

        // -- Assert --
        XCTAssertFalse(fm.fileExists(atPath: sut.currentFileURL.path))
    }

    func testDeleteUserFile_whenExists_shouldDeleteFile() throws {
        // -- Arrange --
        let fm = FileManager.default
        if !fm.fileExists(atPath: sut.currentFileURL.path) {
            try "".write(to: sut.currentFileURL, atomically: true, encoding: .utf8)
        }
        XCTAssertTrue(fm.fileExists(atPath: sut.currentFileURL.path))

        // -- Act --
        sut.deleteUserOnDisk()

        // -- Assert --
        XCTAssertFalse(fm.fileExists(atPath: sut.currentFileURL.path))
    }

    func testDeleteUserFile_whenNotExists_shouldDoNothing() throws {
        // -- Arrange --
        let fm = FileManager.default
        if fm.fileExists(atPath: sut.currentFileURL.path) {
           try fm.removeItem(at: sut.currentFileURL)
        }
        XCTAssertFalse(fm.fileExists(atPath: sut.currentFileURL.path))

        // -- Act --
        sut.deleteUserOnDisk()

        // -- Assert --
        XCTAssertFalse(fm.fileExists(atPath: sut.currentFileURL.path))
    }

    func testcurrentFileURL_returnsURLWithCorrectPath() {
        // -- Arrange --
        let expectedUrl = URL(fileURLWithPath: fixture.fileManager.sentryPath)
            .appendingPathComponent("user.state")

        // -- Act && Assert --
        XCTAssertEqual(sut.currentFileURL, expectedUrl)
    }

    func testpreviousFileURL_returnsURLWithCorrectPath() {
        // -- Arrange --
        let expectedUrl = URL(fileURLWithPath: fixture.fileManager.sentryPath)
            .appendingPathComponent("previous.user.state")

        // -- Act && Assert --
        XCTAssertEqual(sut.previousFileURL, expectedUrl)
    }
}
