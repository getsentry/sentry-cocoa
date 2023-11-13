import XCTest

final class SentryInstallationTests: XCTestCase {
    func testSentryInstallationId() {
        let id = SentryInstallation.id(withCacheDirectoryPath: "/var/tmp/SentryTests")
        XCTAssertEqual(id, SentryInstallation.id(withCacheDirectoryPath: "/var/tmp/SentryTests"))
    }
    
    func testSentryInstallationIds() {
        let id1 = SentryInstallation.id(withCacheDirectoryPath: "/var/tmp/SentryTests1")
        XCTAssertEqual(id1, SentryInstallation.id(withCacheDirectoryPath: "/var/tmp/SentryTests1"))
        
        let id2 = SentryInstallation.id(withCacheDirectoryPath: "/var/tmp/SentryTests2")
        XCTAssertEqual(id2, SentryInstallation.id(withCacheDirectoryPath: "/var/tmp/SentryTests2"))
        
        let id3 = SentryInstallation.id(withCacheDirectoryPath: "/var/tmp/SentryTests3")
        XCTAssertEqual(id3, SentryInstallation.id(withCacheDirectoryPath: "/var/tmp/SentryTests3"))
        
        XCTAssertNotEqual(id1, SentryInstallation.id(withCacheDirectoryPath: "/var/tmp/SentryTests3"))
    }
}
