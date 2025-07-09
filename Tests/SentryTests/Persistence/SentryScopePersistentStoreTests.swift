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

    // MARK: - Context Tests

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

    // MARK: - User Tests

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

    // MARK: - Dist Tests

    func testReadPreviousDistFromDisk_whenValidStringInPreviousDistFile_shouldReturnDecodedString() throws {
        // -- Arrange --
        let fm = FileManager.default
        let dist = "1.0.0"
        let distData = Data(dist.utf8)
        let previousDistFileURL = sut.previousFileURLFor(field: .dist)
        try distData.write(to: previousDistFileURL)
        XCTAssertTrue(fm.fileExists(atPath: previousDistFileURL.path))

        // -- Act --
        let result = try XCTUnwrap(sut.readPreviousDistFromDisk())

        // -- Assert --
        XCTAssertEqual(result, "1.0.0")
    }

    func testReadPreviousDistFromDisk_whenPreviousDistUnavailable_shouldReturnNil() throws {
        // -- Arrange --
        // Check pre-conditions
        let fm = FileManager.default
        let previousDistFileURL = sut.previousFileURLFor(field: .dist)
        if fm.fileExists(atPath: previousDistFileURL.path) {
            try fm.removeItem(at: previousDistFileURL)
        }
        XCTAssertFalse(fm.fileExists(atPath: previousDistFileURL.path))

        // -- Act --
        let result = sut.readPreviousDistFromDisk()

        // -- Assert --
        XCTAssertNil(result)
    }

    func testWriteDistToDisk_whenValidString_shouldWriteToDistFile() throws {
        // -- Arrange --
        let fm = FileManager.default
        let dist = "2.1.0"
        let distFileURL = sut.currentFileURLFor(field: .dist)

        // Check pre-conditions
        XCTAssertFalse(fm.fileExists(atPath: distFileURL.path))

        // -- Act --
        sut.writeDistToDisk(dist: dist)

        // -- Assert --
        XCTAssertTrue(fm.fileExists(atPath: distFileURL.path))
        
        let writtenData = try Data(contentsOf: distFileURL)
        let decodedDist = String(data: writtenData, encoding: .utf8)
        
        XCTAssertEqual(decodedDist, "2.1.0")
    }

    // MARK: - Environment Tests

    func testReadPreviousEnvironmentFromDisk_whenValidStringInPreviousEnvironmentFile_shouldReturnDecodedString() throws {
        // -- Arrange --
        let fm = FileManager.default
        let environment = "production"
        let environmentData = Data(environment.utf8)
        let previousEnvironmentFileURL = sut.previousFileURLFor(field: .environment)
        try environmentData.write(to: previousEnvironmentFileURL)
        XCTAssertTrue(fm.fileExists(atPath: previousEnvironmentFileURL.path))

        // -- Act --
        let result = try XCTUnwrap(sut.readPreviousEnvironmentFromDisk())

        // -- Assert --
        XCTAssertEqual(result, "production")
    }

    func testReadPreviousEnvironmentFromDisk_whenPreviousEnvironmentUnavailable_shouldReturnNil() throws {
        // -- Arrange --
        // Check pre-conditions
        let fm = FileManager.default
        let previousEnvironmentFileURL = sut.previousFileURLFor(field: .environment)
        if fm.fileExists(atPath: previousEnvironmentFileURL.path) {
            try fm.removeItem(at: previousEnvironmentFileURL)
        }
        XCTAssertFalse(fm.fileExists(atPath: previousEnvironmentFileURL.path))

        // -- Act --
        let result = sut.readPreviousEnvironmentFromDisk()

        // -- Assert --
        XCTAssertNil(result)
    }

    func testWriteEnvironmentToDisk_whenValidString_shouldWriteToEnvironmentFile() throws {
        // -- Arrange --
        let fm = FileManager.default
        let environment = "staging"
        let environmentFileURL = sut.currentFileURLFor(field: .environment)

        // Check pre-conditions
        XCTAssertFalse(fm.fileExists(atPath: environmentFileURL.path))

        // -- Act --
        sut.writeEnvironmentToDisk(environment: environment)

        // -- Assert --
        XCTAssertTrue(fm.fileExists(atPath: environmentFileURL.path))
        
        let writtenData = try Data(contentsOf: environmentFileURL)
        let decodedEnvironment = String(data: writtenData, encoding: .utf8)
        
        XCTAssertEqual(decodedEnvironment, "staging")
    }

    // MARK: - File Operation Tests

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

    func testCurrentFileURLFor_dist_returnsURLWithCorrectPath() {
        // -- Arrange --
        let expectedUrl = URL(fileURLWithPath: fixture.fileManager.sentryPath)
            .appendingPathComponent("dist.state")

        // -- Act && Assert --
        XCTAssertEqual(sut.currentFileURLFor(field: .dist), expectedUrl)
    }

    func testPreviousFileURLFor_dist_returnsURLWithCorrectPath() {
        // -- Arrange --
        let expectedUrl = URL(fileURLWithPath: fixture.fileManager.sentryPath)
            .appendingPathComponent("previous.dist.state")

        // -- Act && Assert --
        XCTAssertEqual(sut.previousFileURLFor(field: .dist), expectedUrl)
    }

    func testCurrentFileURLFor_environment_returnsURLWithCorrectPath() {
        // -- Arrange --
        let expectedUrl = URL(fileURLWithPath: fixture.fileManager.sentryPath)
            .appendingPathComponent("environment.state")

        // -- Act && Assert --
        XCTAssertEqual(sut.currentFileURLFor(field: .environment), expectedUrl)
    }

    func testPreviousFileURLFor_environment_returnsURLWithCorrectPath() {
        // -- Arrange --
        let expectedUrl = URL(fileURLWithPath: fixture.fileManager.sentryPath)
            .appendingPathComponent("previous.environment.state")

        // -- Act && Assert --
        XCTAssertEqual(sut.previousFileURLFor(field: .environment), expectedUrl)
    }

    // MARK: - Tags Tests

    func testReadPreviousTagsFromDisk_whenValidJSONInPreviousTagsFile_shouldReturnDecodedTags() throws {
        // -- Arrange --
        let fm = FileManager.default
        let tags = ["key1": "value1", "key2": "value2"]
        let tagsData = try XCTUnwrap(SentrySerialization.data(withJSONObject: tags))
        let previousTagsFileURL = sut.previousFileURLFor(field: .tags)
        try tagsData.write(to: previousTagsFileURL)
        XCTAssertTrue(fm.fileExists(atPath: previousTagsFileURL.path))

        // -- Act --
        let result = try XCTUnwrap(sut.readPreviousTagsFromDisk())

        // -- Assert --
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result["key1"], "value1")
        XCTAssertEqual(result["key2"], "value2")
    }

    func testReadPreviousTagsFromDisk_whenInvalidJSONInPreviousTagsFile_shouldReturnNil() throws {
        // -- Arrange --
        let fm = FileManager.default
        let data = Data("""
            {
                "key1": "value1",
                "key2": 123
            }
            """.utf8)
        let previousTagsFileURL = sut.previousFileURLFor(field: .tags)
        try data.write(to: previousTagsFileURL)
        XCTAssertTrue(fm.fileExists(atPath: previousTagsFileURL.path))

        // -- Act --
        let result = sut.readPreviousTagsFromDisk()

        // -- Assert --
        XCTAssertNil(result)
    }

    func testReadPreviousTagsFromDisk_whenInvalidDataInPreviousTagsFile_shouldReturnNil() throws {
        // -- Arrange --
        let fm = FileManager.default
        let data = Data("<TEST DATA>".utf8)
        let previousTagsFileURL = sut.previousFileURLFor(field: .tags)
        try data.write(to: previousTagsFileURL)
        XCTAssertTrue(fm.fileExists(atPath: previousTagsFileURL.path))

        // -- Act --
        let result = sut.readPreviousTagsFromDisk()

        // -- Assert --
        XCTAssertNil(result)
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

    func testReadPreviousTagsFromDisk_whenPreviousTagsUnavailable_shouldReturnNil() throws {
        // -- Arrange --
        // Check pre-conditions
        let fm = FileManager.default
        let previousTagsFileURL = sut.previousFileURLFor(field: .tags)
        if fm.fileExists(atPath: previousTagsFileURL.path) {
            try fm.removeItem(at: previousTagsFileURL)
        }
        XCTAssertFalse(fm.fileExists(atPath: previousTagsFileURL.path))

        // -- Act --
        let result = sut.readPreviousTagsFromDisk()

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

    func testWriteTagsToDisk_whenValidTags_shouldWriteToTagsFile() throws {
        // -- Arrange --
        let fm = FileManager.default
        let tags = ["key1": "value1", "key2": "value2"]
        let tagsFileURL = sut.currentFileURLFor(field: .tags)

        // Check pre-conditions
        if fm.fileExists(atPath: tagsFileURL.path) {
            try fm.removeItem(at: tagsFileURL)
        }
        XCTAssertFalse(fm.fileExists(atPath: tagsFileURL.path))

        // -- Act --
        sut.writeTagsToDisk(tags: tags)

        // -- Assert --
        XCTAssertTrue(fm.fileExists(atPath: tagsFileURL.path))
        
        let writtenData = try Data(contentsOf: tagsFileURL)
        let decodedTags = try XCTUnwrap(SentrySerialization.deserializeDictionary(fromJsonData: writtenData)) as? [String: String]
        
        XCTAssertEqual(decodedTags?.count, 2)
        XCTAssertEqual(decodedTags?["key1"], "value1")
        XCTAssertEqual(decodedTags?["key2"], "value2")
    }

    func testWriteTagsToDisk_whenInvalidTags_shouldNotWriteToTagsFile() throws {
        // -- Arrange --
        let fm = FileManager.default
        let tags = ["key1": "value1", "key2": "value2"]
        let tagsFileURL = sut.currentFileURLFor(field: .tags)
        if fm.fileExists(atPath: tagsFileURL.path) {
            try fm.removeItem(at: tagsFileURL)
        }

        // Check pre-conditions
        XCTAssertFalse(fm.fileExists(atPath: tagsFileURL.path))

        // -- Act --
        sut.writeTagsToDisk(tags: tags)

        // -- Assert --
        XCTAssertTrue(fm.fileExists(atPath: tagsFileURL.path))
    }

    // MARK: - File Operation Tests

    func testCurrentFileURLFor_tags_returnsURLWithCorrectPath() {
        // -- Arrange --
        let expectedUrl = URL(fileURLWithPath: fixture.fileManager.sentryPath)
            .appendingPathComponent("tags.state")

        // -- Act && Assert --
        XCTAssertEqual(sut.currentFileURLFor(field: .tags), expectedUrl)
    }

    func testPreviousFileURLFor_tags_returnsURLWithCorrectPath() {
        // -- Arrange --
        let expectedUrl = URL(fileURLWithPath: fixture.fileManager.sentryPath)
            .appendingPathComponent("previous.tags.state")

        // -- Act && Assert --
        XCTAssertEqual(sut.previousFileURLFor(field: .tags), expectedUrl)
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
    
    func testReadPreviousFingerprintFromDisk_whenNonStringElementsInPreviousFingerprintFile_shouldReturnStringOnly() throws {
        // -- Arrange --
        let fm = FileManager.default
        let data = Data("[\"a\", 1]".utf8)
        let previousFingerprintFileURL = sut.previousFileURLFor(field: .fingerprint)
        try data.write(to: previousFingerprintFileURL)
        XCTAssertTrue(fm.fileExists(atPath: previousFingerprintFileURL.path))

        // -- Act --
        let result = sut.readPreviousFingerprintFromDisk()

        // -- Assert --
        XCTAssertEqual(result, ["a"])
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
        let distFileURL = sut.currentFileURLFor(field: .dist)
        let environmentFileURL = sut.currentFileURLFor(field: .environment)
        let tagsFileURL = sut.currentFileURLFor(field: .tags)
        let extrasFileURL = sut.currentFileURLFor(field: .extras)
        let fingerprintFileURL = sut.currentFileURLFor(field: .fingerprint)
        
        // Create test files
        try "context data".write(to: contextFileURL, atomically: true, encoding: .utf8)
        try "user data".write(to: userFileURL, atomically: true, encoding: .utf8)
        try "dist data".write(to: distFileURL, atomically: true, encoding: .utf8)
        try "environment data".write(to: environmentFileURL, atomically: true, encoding: .utf8)
        try "tags data".write(to: tagsFileURL, atomically: true, encoding: .utf8)
        try "extras data".write(to: extrasFileURL, atomically: true, encoding: .utf8)
        try "fingerprint data".write(to: fingerprintFileURL, atomically: true, encoding: .utf8)
        
        XCTAssertTrue(fm.fileExists(atPath: contextFileURL.path))
        XCTAssertTrue(fm.fileExists(atPath: userFileURL.path))
        XCTAssertTrue(fm.fileExists(atPath: distFileURL.path))
        XCTAssertTrue(fm.fileExists(atPath: environmentFileURL.path))
        XCTAssertTrue(fm.fileExists(atPath: tagsFileURL.path))
        XCTAssertTrue(fm.fileExists(atPath: extrasFileURL.path))
        XCTAssertTrue(fm.fileExists(atPath: fingerprintFileURL.path))

        // -- Act --
        sut.deleteAllCurrentState()

        // -- Assert --
        XCTAssertFalse(fm.fileExists(atPath: contextFileURL.path))
        XCTAssertFalse(fm.fileExists(atPath: userFileURL.path))
        XCTAssertFalse(fm.fileExists(atPath: distFileURL.path))
        XCTAssertFalse(fm.fileExists(atPath: environmentFileURL.path))
        XCTAssertFalse(fm.fileExists(atPath: tagsFileURL.path))
        XCTAssertFalse(fm.fileExists(atPath: extrasFileURL.path))
        XCTAssertFalse(fm.fileExists(atPath: fingerprintFileURL.path))
    }

    func testDeleteAllPreviousState_shouldDeleteAllPreviousFiles() throws {
        // -- Arrange --
        let fm = FileManager.default
        let previousContextFileURL = sut.previousFileURLFor(field: .context)
        let previousUserFileURL = sut.previousFileURLFor(field: .user)
        let previousDistFileURL = sut.previousFileURLFor(field: .dist)
        let previousEnvironmentFileURL = sut.previousFileURLFor(field: .environment)
        let previousTagsFileURL = sut.previousFileURLFor(field: .tags)
        let previousExtrasFileURL = sut.previousFileURLFor(field: .extras)
        let previousFingerprintFileURL = sut.previousFileURLFor(field: .fingerprint)
        
        // Create test files
        try "previous context data".write(to: previousContextFileURL, atomically: true, encoding: .utf8)
        try "previous user data".write(to: previousUserFileURL, atomically: true, encoding: .utf8)
        try "previous dist data".write(to: previousDistFileURL, atomically: true, encoding: .utf8)
        try "previous environment data".write(to: previousEnvironmentFileURL, atomically: true, encoding: .utf8)
        try "previous tags data".write(to: previousTagsFileURL, atomically: true, encoding: .utf8)
        try "previous extras data".write(to: previousExtrasFileURL, atomically: true, encoding: .utf8)
        try "previous fingerprint data".write(to: previousFingerprintFileURL, atomically: true, encoding: .utf8)
        
        XCTAssertTrue(fm.fileExists(atPath: previousContextFileURL.path))
        XCTAssertTrue(fm.fileExists(atPath: previousUserFileURL.path))
        XCTAssertTrue(fm.fileExists(atPath: previousDistFileURL.path))
        XCTAssertTrue(fm.fileExists(atPath: previousEnvironmentFileURL.path))
        XCTAssertTrue(fm.fileExists(atPath: previousTagsFileURL.path))
        XCTAssertTrue(fm.fileExists(atPath: previousExtrasFileURL.path))
        XCTAssertTrue(fm.fileExists(atPath: previousFingerprintFileURL.path))

        // -- Act --
        sut.deleteAllPreviousState()

        // -- Assert --
        XCTAssertFalse(fm.fileExists(atPath: previousContextFileURL.path))
        XCTAssertFalse(fm.fileExists(atPath: previousUserFileURL.path))
        XCTAssertFalse(fm.fileExists(atPath: previousDistFileURL.path))
        XCTAssertFalse(fm.fileExists(atPath: previousEnvironmentFileURL.path))
        XCTAssertFalse(fm.fileExists(atPath: previousTagsFileURL.path))
        XCTAssertFalse(fm.fileExists(atPath: previousExtrasFileURL.path))
        XCTAssertFalse(fm.fileExists(atPath: previousFingerprintFileURL.path))
    }
}
