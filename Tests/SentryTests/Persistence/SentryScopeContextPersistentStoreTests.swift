@testable import Sentry
import SentryTestUtils
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

        func getSut() -> SentryScopeContextPersistentStore {
            return SentryScopeContextPersistentStore(fileManager: fileManager)
        }
    }

    private var fixture: Fixture!
    private var sut: SentryScopeContextPersistentStore!

    override func setUpWithError() throws {
        super.setUp()

        fixture = try Fixture()
        sut = fixture.getSut()
    }

    func testMoveContextFilesToPreviousContextFiles_whenPreviousContextFileAvailable_shouldMoveFileToPreviousPath() throws {
        // -- Arrange --
        let fm = FileManager.default
        let data = Data("<TEST DATA>".utf8)

        // Check pre-conditions
        XCTAssertFalse(fm.fileExists(atPath: sut.contextFileURL.path))
        XCTAssertFalse(fm.fileExists(atPath: sut.previousContextFileURL.path))

        fm.createFile(atPath: sut.contextFileURL.path, contents: data)

        XCTAssertTrue(fm.fileExists(atPath: sut.contextFileURL.path))
        XCTAssertFalse(fm.fileExists(atPath: sut.previousContextFileURL.path))

        // -- Act --
        sut.moveContextFileToPreviousContextFile()

        // -- Assert --
        XCTAssertFalse(fm.fileExists(atPath: sut.contextFileURL.path))
        XCTAssertTrue(fm.fileExists(atPath: sut.previousContextFileURL.path))

        let previousContextData = try Data(contentsOf: URL(fileURLWithPath: sut.previousContextFileURL.path))
        XCTAssertEqual(previousContextData, data)
    }
}
