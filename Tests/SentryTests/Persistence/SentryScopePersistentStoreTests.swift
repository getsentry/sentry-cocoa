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

    // MARK: - Level Tests

    func testReadPreviousLevelFromDisk_whenValidDataInPreviousLevelFile_shouldReturnDecodedLevel() throws {
        // -- Arrange --
        let fm = FileManager.default
        let levelData = Data("\(SentryLevel.fatal.rawValue)".utf8)
        let previousLevelFileURL = sut.previousFileURLFor(field: .level)
        try levelData.write(to: previousLevelFileURL)
        XCTAssertTrue(fm.fileExists(atPath: previousLevelFileURL.path))

        // -- Act --
        let result = sut.readPreviousLevelFromDisk()

        // -- Assert --
        XCTAssertEqual(result, .fatal)
    }

    func testReadPreviousLevelFromDisk_whenInvalidDataInPreviousLevelFile_shouldReturnNoneLevel() throws {
        // -- Arrange --
        let fm = FileManager.default
        let levelData = Data("invalid".utf8)
        let previousLevelFileURL = sut.previousFileURLFor(field: .level)
        try levelData.write(to: previousLevelFileURL)
        XCTAssertTrue(fm.fileExists(atPath: previousLevelFileURL.path))

        // -- Act --
        let result = sut.readPreviousLevelFromDisk()

        // -- Assert --
        XCTAssertEqual(result, .none)
    }

    func testReadPreviousLevelFromDisk_whenPreviousLevelFileUnavailable_shouldReturnNoneLevel() throws {
        // -- Arrange --
        let fm = FileManager.default
        let previousLevelFileURL = sut.previousFileURLFor(field: .level)
        if fm.fileExists(atPath: previousLevelFileURL.path) {
            try fm.removeItem(at: previousLevelFileURL)
        }
        XCTAssertFalse(fm.fileExists(atPath: previousLevelFileURL.path))

        // -- Act --
        let result = sut.readPreviousLevelFromDisk()

        // -- Assert --
        XCTAssertEqual(result, .none)
    }

    func testWriteLevelToDisk_whenValidLevel_shouldWriteToLevelFile() throws {
        // -- Arrange --
        let fm = FileManager.default
        let level = NSNumber(value: SentryLevel.fatal.rawValue)
        let levelFileURL = sut.currentFileURLFor(field: .level)

        // Check pre-conditions
        XCTAssertFalse(fm.fileExists(atPath: levelFileURL.path))

        // -- Act --
        sut.writeLevelToDisk(level: level)

        // -- Assert --
        XCTAssertTrue(fm.fileExists(atPath: levelFileURL.path))
        
        let writtenData = try Data(contentsOf: levelFileURL)
        let writtenString = String(data: writtenData, encoding: .utf8)
        XCTAssertEqual(writtenString, "\(SentryLevel.fatal.rawValue)")
    }

    // MARK: - Extras Tests

    func testReadPreviousExtrasFromDisk_whenValidJSONInPreviousExtrasFile_shouldReturnDecodedData() throws {
        // -- Arrange --
        let fm = FileManager.default
        let extras: [String: Any] = ["key1": "value1", "key2": 42, "key3": true]
        let extrasData = try XCTUnwrap(SentrySerialization.data(withJSONObject: extras))
        let previousExtrasFileURL = sut.previousFileURLFor(field: .extras)
        try extrasData.write(to: previousExtrasFileURL)
        XCTAssertTrue(fm.fileExists(atPath: previousExtrasFileURL.path))

        // -- Act --
        let result = try XCTUnwrap(sut.readPreviousExtrasFromDisk())

        // -- Assert --
        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result["key1"] as? String, "value1")
        XCTAssertEqual(result["key2"] as? Int, 42)
        XCTAssertEqual(result["key3"] as? Bool, true)
    }

    func testReadPreviousExtrasFromDisk_whenInvalidJSONInPreviousExtrasFile_shouldReturnNil() throws {
        // -- Arrange --
        let fm = FileManager.default
        let data = Data("<TEST DATA>".utf8)
        let previousExtrasFileURL = sut.previousFileURLFor(field: .extras)
        try data.write(to: previousExtrasFileURL)
        XCTAssertTrue(fm.fileExists(atPath: previousExtrasFileURL.path))

        // -- Act --
        let result = sut.readPreviousExtrasFromDisk()

        // -- Assert --
        XCTAssertNil(result)
    }

    func testReadPreviousExtrasFromDisk_whenPreviousExtrasFileUnavailable_shouldReturnNil() throws {
        // -- Arrange --
        let fm = FileManager.default
        let previousExtrasFileURL = sut.previousFileURLFor(field: .extras)
        if fm.fileExists(atPath: previousExtrasFileURL.path) {
            try fm.removeItem(at: previousExtrasFileURL)
        }
        XCTAssertFalse(fm.fileExists(atPath: previousExtrasFileURL.path))

        // -- Act --
        let result = sut.readPreviousExtrasFromDisk()

        // -- Assert --
        XCTAssertNil(result)
    }

    func testWriteExtrasToDisk_whenValidExtras_shouldWriteToExtrasFile() throws {
        // -- Arrange --
        let fm = FileManager.default
        let extras: [String: Any] = ["key1": "value1", "key2": 42, "key3": true]
        let extrasFileURL = sut.currentFileURLFor(field: .extras)

        // Check pre-conditions
        XCTAssertFalse(fm.fileExists(atPath: extrasFileURL.path))

        // -- Act --
        sut.writeExtrasToDisk(extras: extras)

        // -- Assert --
        XCTAssertTrue(fm.fileExists(atPath: extrasFileURL.path))
        
        let writtenData = try Data(contentsOf: extrasFileURL)
        let serializedData = try XCTUnwrap(SentrySerialization.deserializeDictionary(fromJsonData: writtenData))
        
        XCTAssertEqual(serializedData.count, 3)
        XCTAssertEqual(serializedData["key1"] as? String, "value1")
        XCTAssertEqual(serializedData["key2"] as? Int, 42)
        XCTAssertEqual(serializedData["key3"] as? Bool, true)
    }

    func testWriteExtrasToDisk_whenInvalidJSONExtras_shouldNotWriteToExtrasFile() throws {
        // -- Arrange --
        let fm = FileManager.default
        let extras: [String: Any] = ["key1": Double.infinity]
        let extrasFileURL = sut.currentFileURLFor(field: .extras)
        if fm.fileExists(atPath: extrasFileURL.path) {
            try fm.removeItem(at: extrasFileURL)
        }

        // Check pre-conditions
        XCTAssertFalse(fm.fileExists(atPath: extrasFileURL.path))

        // -- Act --
        sut.writeExtrasToDisk(extras: extras)

        // -- Assert --
        XCTAssertFalse(fm.fileExists(atPath: extrasFileURL.path))
    }

    // MARK: - Fingerprint Tests

    func testReadPreviousFingerprintFromDisk_whenValidJSONInPreviousFingerprintFile_shouldReturnDecodedData() throws {
        // -- Arrange --
        let fm = FileManager.default
        let fingerprint = ["fp1", "fp2", "fp3"]
        let fingerprintData = try XCTUnwrap(SentrySerialization.data(withJSONObject: fingerprint))
        let previousFingerprintFileURL = sut.previousFileURLFor(field: .fingerprint)
        try fingerprintData.write(to: previousFingerprintFileURL)
        XCTAssertTrue(fm.fileExists(atPath: previousFingerprintFileURL.path))

        // -- Act --
        let result = try XCTUnwrap(sut.readPreviousFingerprintFromDisk())

        // -- Assert --
        XCTAssertEqual(result, fingerprint)
    }

    func testReadPreviousFingerprintFromDisk_whenInvalidJSONInPreviousFingerprintFile_shouldReturnNil() throws {
        // -- Arrange --
        let fm = FileManager.default
        let data = Data("<TEST DATA>".utf8)
        let previousFingerprintFileURL = sut.previousFileURLFor(field: .fingerprint)
        try data.write(to: previousFingerprintFileURL)
        XCTAssertTrue(fm.fileExists(atPath: previousFingerprintFileURL.path))

        // -- Act --
        let result = sut.readPreviousFingerprintFromDisk()

        // -- Assert --
        XCTAssertNil(result)
    }

    func testReadPreviousFingerprintFromDisk_whenPreviousFingerprintFileUnavailable_shouldReturnNil() throws {
        // -- Arrange --
        let fm = FileManager.default
        let previousFingerprintFileURL = sut.previousFileURLFor(field: .fingerprint)
        if fm.fileExists(atPath: previousFingerprintFileURL.path) {
            try fm.removeItem(at: previousFingerprintFileURL)
        }
        XCTAssertFalse(fm.fileExists(atPath: previousFingerprintFileURL.path))

        // -- Act --
        let result = sut.readPreviousFingerprintFromDisk()

        // -- Assert --
        XCTAssertNil(result)
    }

    func testWriteFingerprintToDisk_whenValidFingerprint_shouldWriteToFingerprintFile() throws {
        // -- Arrange --
        let fm = FileManager.default
        let fingerprint = ["fp1", "fp2", "fp3"]
        let fingerprintFileURL = sut.currentFileURLFor(field: .fingerprint)

        // Check pre-conditions
        XCTAssertFalse(fm.fileExists(atPath: fingerprintFileURL.path))

        // -- Act --
        sut.writeFingerprintToDisk(fingerprint: fingerprint)

        // -- Assert --
        XCTAssertTrue(fm.fileExists(atPath: fingerprintFileURL.path))
        
        let writtenData = try Data(contentsOf: fingerprintFileURL)
        let serializedData = try XCTUnwrap(SentrySerialization.deserializeArray(fromJsonData: writtenData))
        
        XCTAssertEqual(serializedData.count, 3)
        XCTAssertEqual(serializedData[0] as? String, "fp1")
        XCTAssertEqual(serializedData[1] as? String, "fp2")
        XCTAssertEqual(serializedData[2] as? String, "fp3")
    }

    func testDeleteAllCurrentState_shouldDeleteAllCurrentFiles() throws {
        // -- Arrange --
        let fm = FileManager.default
        let contextFileURL = sut.currentFileURLFor(field: .context)
        let userFileURL = sut.currentFileURLFor(field: .user)
        let levelFileURL = sut.currentFileURLFor(field: .level)
        let extrasFileURL = sut.currentFileURLFor(field: .extras)
        let fingerprintFileURL = sut.currentFileURLFor(field: .fingerprint)
        
        // Create test files
        try "context data".write(to: contextFileURL, atomically: true, encoding: .utf8)
        try "user data".write(to: userFileURL, atomically: true, encoding: .utf8)
        try "level data".write(to: levelFileURL, atomically: true, encoding: .utf8)
        try "extras data".write(to: extrasFileURL, atomically: true, encoding: .utf8)
        try "fingerprint data".write(to: fingerprintFileURL, atomically: true, encoding: .utf8)
        
        XCTAssertTrue(fm.fileExists(atPath: contextFileURL.path))
        XCTAssertTrue(fm.fileExists(atPath: userFileURL.path))
        XCTAssertTrue(fm.fileExists(atPath: levelFileURL.path))
        XCTAssertTrue(fm.fileExists(atPath: extrasFileURL.path))
        XCTAssertTrue(fm.fileExists(atPath: fingerprintFileURL.path))

        // -- Act --
        sut.deleteAllCurrentState()

        // -- Assert --
        XCTAssertFalse(fm.fileExists(atPath: contextFileURL.path))
        XCTAssertFalse(fm.fileExists(atPath: userFileURL.path))
        XCTAssertFalse(fm.fileExists(atPath: levelFileURL.path))
        XCTAssertFalse(fm.fileExists(atPath: extrasFileURL.path))
        XCTAssertFalse(fm.fileExists(atPath: fingerprintFileURL.path))
    }

    func testDeleteAllPreviousState_shouldDeleteAllPreviousFiles() throws {
        // -- Arrange --
        let fm = FileManager.default
        let previousContextFileURL = sut.previousFileURLFor(field: .context)
        let previousUserFileURL = sut.previousFileURLFor(field: .user)
        let previousLevelFileURL = sut.previousFileURLFor(field: .level)
        let previousExtrasFileURL = sut.previousFileURLFor(field: .extras)
        let previousFingerprintFileURL = sut.previousFileURLFor(field: .fingerprint)
        
        // Create test files
        try "previous context data".write(to: previousContextFileURL, atomically: true, encoding: .utf8)
        try "previous user data".write(to: previousUserFileURL, atomically: true, encoding: .utf8)
        try "previous level data".write(to: previousLevelFileURL, atomically: true, encoding: .utf8)
        try "previous extras data".write(to: previousExtrasFileURL, atomically: true, encoding: .utf8)
        try "previous fingerprint data".write(to: previousFingerprintFileURL, atomically: true, encoding: .utf8)
        
        XCTAssertTrue(fm.fileExists(atPath: previousContextFileURL.path))
        XCTAssertTrue(fm.fileExists(atPath: previousUserFileURL.path))
        XCTAssertTrue(fm.fileExists(atPath: previousLevelFileURL.path))
        XCTAssertTrue(fm.fileExists(atPath: previousExtrasFileURL.path))
        XCTAssertTrue(fm.fileExists(atPath: previousFingerprintFileURL.path))

        // -- Act --
        sut.deleteAllPreviousState()

        // -- Assert --
        XCTAssertFalse(fm.fileExists(atPath: previousContextFileURL.path))
        XCTAssertFalse(fm.fileExists(atPath: previousUserFileURL.path))
        XCTAssertFalse(fm.fileExists(atPath: previousLevelFileURL.path))
        XCTAssertFalse(fm.fileExists(atPath: previousExtrasFileURL.path))
        XCTAssertFalse(fm.fileExists(atPath: previousFingerprintFileURL.path))
    }
}
