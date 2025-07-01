@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

class SentryScopeBasePersistentStoreTests: XCTestCase {
    private static let dsn = TestConstants.dsnForTestCase(type: SentryScopeBasePersistentStoreTests.self)

    private class Fixture {
        let fileManager: TestFileManager
        let fileName: String

        init() throws {
            let options = Options()
            options.dsn = SentryScopeBasePersistentStoreTests.dsn
            fileManager = try TestFileManager(options: options)
            fileName = "test"
        }

        func getSut() -> SentryScopeBasePersistentStore {
            return SentryScopeBasePersistentStore(fileManager: fileManager, fileName: fileName)
        }
    }

    private var fixture: Fixture!
    private var sut: SentryScopeBasePersistentStore!

    override func setUpWithError() throws {
        super.setUp()

        fixture = try Fixture()
        sut = fixture.getSut()
    }

    override func tearDown() {
        super.tearDown()
        fixture.fileManager.deleteAllFolders()
    }

    // MARK: - Initialization Tests

    func testInit_withValidParameters_shouldCreateInstance() {
        // -- Act & Assert --
        XCTAssertNotNil(sut)
    }

    func testInit_withDifferentFileName_shouldCreateInstance() {
        // -- Arrange --
        let customFileName = "custom"
        
        // -- Act --
        let customSut = SentryScopeBasePersistentStore(fileManager: fixture.fileManager, fileName: customFileName)
        
        // -- Assert --
        XCTAssertNotNil(customSut)
    }

    // MARK: - File URL Tests

    func testCurrentFileURL_shouldReturnCorrectPath() {
        // -- Arrange --
        let expectedURL = URL(fileURLWithPath: fixture.fileManager.sentryPath)
            .appendingPathComponent("\(fixture.fileName).state")

        // -- Act & Assert --
        XCTAssertEqual(sut.currentFileURL, expectedURL)
    }

    func testPreviousFileURL_shouldReturnCorrectPath() {
        // -- Arrange --
        let expectedURL = URL(fileURLWithPath: fixture.fileManager.sentryPath)
            .appendingPathComponent("previous.\(fixture.fileName).state")

        // -- Act & Assert --
        XCTAssertEqual(sut.previousFileURL, expectedURL)
    }

    func testFileURLs_withDifferentFileName_shouldReturnDifferentPaths() {
        // -- Arrange --
        let customFileName = "custom"
        let customSut = SentryScopeBasePersistentStore(fileManager: fixture.fileManager, fileName: customFileName)
        
        let expectedCurrentURL = URL(fileURLWithPath: fixture.fileManager.sentryPath)
            .appendingPathComponent("\(customFileName).state")
        let expectedPreviousURL = URL(fileURLWithPath: fixture.fileManager.sentryPath)
            .appendingPathComponent("previous.\(customFileName).state")

        // -- Act & Assert --
        XCTAssertEqual(customSut.currentFileURL, expectedCurrentURL)
        XCTAssertEqual(customSut.previousFileURL, expectedPreviousURL)
    }

    // MARK: - Move Current File to Previous File Tests

    func testMoveCurrentFileToPreviousFile_whenCurrentFileExists_shouldMoveFile() throws {
        // -- Arrange --
        let fm = FileManager.default
        let data = Data("<TEST DATA>".utf8)

        // Clean up any existing files
        if fm.fileExists(atPath: sut.previousFileURL.path) {
            try fm.removeItem(at: sut.previousFileURL)
        }
        if fm.fileExists(atPath: sut.currentFileURL.path) {
            try fm.removeItem(at: sut.currentFileURL)
        }
        
        // Create current file
        fm.createFile(atPath: sut.currentFileURL.path, contents: data)

        XCTAssertTrue(fm.fileExists(atPath: sut.currentFileURL.path))
        XCTAssertFalse(fm.fileExists(atPath: sut.previousFileURL.path))

        // -- Act --
        sut.moveCurrentFileToPreviousFile()

        // -- Assert --
        XCTAssertFalse(fm.fileExists(atPath: sut.currentFileURL.path))
        XCTAssertTrue(fm.fileExists(atPath: sut.previousFileURL.path))

        let previousFileData = try Data(contentsOf: sut.previousFileURL)
        XCTAssertEqual(previousFileData, data)
    }

    func testMoveCurrentFileToPreviousFile_whenCurrentFileNotExists_shouldNotThrow() throws {
        // -- Arrange --
        let fm = FileManager.default
        
        // Clean up any existing files
        if fm.fileExists(atPath: sut.previousFileURL.path) {
            try fm.removeItem(at: sut.previousFileURL)
        }
        if fm.fileExists(atPath: sut.currentFileURL.path) {
            try fm.removeItem(at: sut.currentFileURL)
        }
        
        XCTAssertFalse(fm.fileExists(atPath: sut.currentFileURL.path))
        XCTAssertFalse(fm.fileExists(atPath: sut.previousFileURL.path))

        // -- Act & Assert --
        XCTAssertNoThrow(sut.moveCurrentFileToPreviousFile())
        XCTAssertFalse(fm.fileExists(atPath: sut.currentFileURL.path))
        XCTAssertFalse(fm.fileExists(atPath: sut.previousFileURL.path))
    }

    func testMoveCurrentFileToPreviousFile_whenPreviousFileExists_shouldOverwritePreviousFile() throws {
        // -- Arrange --
        let fm = FileManager.default
        let oldData = Data("<OLD DATA>".utf8)
        let newData = Data("<NEW DATA>".utf8)

        // Create both files
        fm.createFile(atPath: sut.previousFileURL.path, contents: oldData)
        fm.createFile(atPath: sut.currentFileURL.path, contents: newData)

        XCTAssertTrue(fm.fileExists(atPath: sut.currentFileURL.path))
        XCTAssertTrue(fm.fileExists(atPath: sut.previousFileURL.path))

        // -- Act --
        sut.moveCurrentFileToPreviousFile()

        // -- Assert --
        XCTAssertFalse(fm.fileExists(atPath: sut.currentFileURL.path))
        XCTAssertTrue(fm.fileExists(atPath: sut.previousFileURL.path))

        let previousFileData = try Data(contentsOf: sut.previousFileURL)
        XCTAssertEqual(previousFileData, newData)
        XCTAssertNotEqual(previousFileData, oldData)
    }

    // MARK: - Read Previous State Tests

    func testReadPreviousStateFromDisk_whenPreviousFileExists_shouldReturnData() throws {
        // -- Arrange --
        let fm = FileManager.default
        let data = Data("<TEST DATA>".utf8)
        
        fm.createFile(atPath: sut.previousFileURL.path, contents: data)
        XCTAssertTrue(fm.fileExists(atPath: sut.previousFileURL.path))

        // -- Act --
        let result = sut.readPreviousStateFromDisk()

        // -- Assert --
        XCTAssertNotNil(result)
        XCTAssertEqual(result, data)
    }

    func testReadPreviousStateFromDisk_whenPreviousFileNotExists_shouldReturnNil() throws {
        // -- Arrange --
        let fm = FileManager.default
        
        if fm.fileExists(atPath: sut.previousFileURL.path) {
            try fm.removeItem(at: sut.previousFileURL)
        }
        XCTAssertFalse(fm.fileExists(atPath: sut.previousFileURL.path))

        // -- Act --
        let result = sut.readPreviousStateFromDisk()

        // -- Assert --
        XCTAssertNil(result)
    }

    // MARK: - Write State Tests

    func testWriteStateToDisk_whenValidData_shouldWriteToCurrentFile() throws {
        // -- Arrange --
        let fm = FileManager.default
        let data = Data("<TEST DATA>".utf8)
        
        XCTAssertFalse(fm.fileExists(atPath: sut.currentFileURL.path))

        // -- Act --
        sut.writeStateToDisk(data: data)

        // -- Assert --
        XCTAssertTrue(fm.fileExists(atPath: sut.currentFileURL.path))
        
        let writtenData = try Data(contentsOf: sut.currentFileURL)
        XCTAssertEqual(writtenData, data)
    }

    func testWriteStateToDisk_whenFileExists_shouldOverwriteFile() throws {
        // -- Arrange --
        let fm = FileManager.default
        let oldData = Data("<OLD DATA>".utf8)
        let newData = Data("<NEW DATA>".utf8)
        
        fm.createFile(atPath: sut.currentFileURL.path, contents: oldData)
        XCTAssertTrue(fm.fileExists(atPath: sut.currentFileURL.path))

        // -- Act --
        sut.writeStateToDisk(data: newData)

        // -- Assert --
        XCTAssertTrue(fm.fileExists(atPath: sut.currentFileURL.path))
        
        let writtenData = try Data(contentsOf: sut.currentFileURL)
        XCTAssertEqual(writtenData, newData)
        XCTAssertNotEqual(writtenData, oldData)
    }

    func testWriteStateToDisk_withEmptyData_shouldWriteEmptyFile() throws {
        // -- Arrange --
        let fm = FileManager.default
        let data = Data()
        
        XCTAssertFalse(fm.fileExists(atPath: sut.currentFileURL.path))

        // -- Act --
        sut.writeStateToDisk(data: data)

        // -- Assert --
        XCTAssertTrue(fm.fileExists(atPath: sut.currentFileURL.path))
        
        let writtenData = try Data(contentsOf: sut.currentFileURL)
        XCTAssertEqual(writtenData, data)
        XCTAssertTrue(writtenData.isEmpty)
    }

    // MARK: - Delete State Tests

    func testDeleteStateOnDisk_whenCurrentFileExists_shouldDeleteFile() throws {
        // -- Arrange --
        let fm = FileManager.default
        let data = Data("<TEST DATA>".utf8)
        
        fm.createFile(atPath: sut.currentFileURL.path, contents: data)
        XCTAssertTrue(fm.fileExists(atPath: sut.currentFileURL.path))

        // -- Act --
        sut.deleteStateOnDisk()

        // -- Assert --
        XCTAssertFalse(fm.fileExists(atPath: sut.currentFileURL.path))
    }

    func testDeleteStateOnDisk_whenCurrentFileNotExists_shouldNotThrow() throws {
        // -- Arrange --
        let fm = FileManager.default
        
        if fm.fileExists(atPath: sut.currentFileURL.path) {
            try fm.removeItem(at: sut.currentFileURL)
        }
        XCTAssertFalse(fm.fileExists(atPath: sut.currentFileURL.path))

        // -- Act & Assert --
        XCTAssertNoThrow(sut.deleteStateOnDisk())
        XCTAssertFalse(fm.fileExists(atPath: sut.currentFileURL.path))
    }

    func testDeletePreviousStateOnDisk_whenPreviousFileExists_shouldDeleteFile() throws {
        // -- Arrange --
        let fm = FileManager.default
        let data = Data("<TEST DATA>".utf8)
        
        fm.createFile(atPath: sut.previousFileURL.path, contents: data)
        XCTAssertTrue(fm.fileExists(atPath: sut.previousFileURL.path))

        // -- Act --
        sut.deletePreviousStateOnDisk()

        // -- Assert --
        XCTAssertFalse(fm.fileExists(atPath: sut.previousFileURL.path))
    }

    func testDeletePreviousStateOnDisk_whenPreviousFileNotExists_shouldNotThrow() throws {
        // -- Arrange --
        let fm = FileManager.default
        
        if fm.fileExists(atPath: sut.previousFileURL.path) {
            try fm.removeItem(at: sut.previousFileURL)
        }
        XCTAssertFalse(fm.fileExists(atPath: sut.previousFileURL.path))

        // -- Act & Assert --
        XCTAssertNoThrow(sut.deletePreviousStateOnDisk())
        XCTAssertFalse(fm.fileExists(atPath: sut.previousFileURL.path))
    }

    // MARK: - Integration Tests

    func testFullWorkflow_shouldWorkCorrectly() throws {
        // -- Arrange --
        let fm = FileManager.default
        let data1 = Data("<DATA 1>".utf8)
        let data2 = Data("<DATA 2>".utf8)
        
        // Clean up any existing files
        if fm.fileExists(atPath: sut.previousFileURL.path) {
            try fm.removeItem(at: sut.previousFileURL)
        }
        if fm.fileExists(atPath: sut.currentFileURL.path) {
            try fm.removeItem(at: sut.currentFileURL)
        }

        // -- Act & Assert --
        
        // Step 1: Write initial data
        sut.writeStateToDisk(data: data1)
        XCTAssertTrue(fm.fileExists(atPath: sut.currentFileURL.path))
        XCTAssertFalse(fm.fileExists(atPath: sut.previousFileURL.path))
        
        // Step 2: Move current to previous
        sut.moveCurrentFileToPreviousFile()
        XCTAssertFalse(fm.fileExists(atPath: sut.currentFileURL.path))
        XCTAssertTrue(fm.fileExists(atPath: sut.previousFileURL.path))
        
        // Step 3: Read previous data
        let readData = sut.readPreviousStateFromDisk()
        XCTAssertEqual(readData, data1)
        
        // Step 4: Write new data
        sut.writeStateToDisk(data: data2)
        XCTAssertTrue(fm.fileExists(atPath: sut.currentFileURL.path))
        XCTAssertTrue(fm.fileExists(atPath: sut.previousFileURL.path))
        
        // Step 5: Delete current file
        sut.deleteStateOnDisk()
        XCTAssertFalse(fm.fileExists(atPath: sut.currentFileURL.path))
        XCTAssertTrue(fm.fileExists(atPath: sut.previousFileURL.path))
        
        // Step 6: Delete previous file
        sut.deletePreviousStateOnDisk()
        XCTAssertFalse(fm.fileExists(atPath: sut.currentFileURL.path))
        XCTAssertFalse(fm.fileExists(atPath: sut.previousFileURL.path))
    }
} 
