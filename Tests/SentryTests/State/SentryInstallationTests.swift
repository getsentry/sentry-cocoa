import XCTest

final class SentryInstallationTests: XCTestCase {
    var basePath: String!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        // FileManager().temporaryDirectory already has a trailting slash
        basePath = "\(FileManager().temporaryDirectory)\(UUID().uuidString)"
        try FileManager().createDirectory(atPath: basePath, withIntermediateDirectories: true)
        print("base path: \(basePath!)")
    }
    
    override func tearDownWithError() throws {
        super.tearDown()
        try FileManager().removeItem(atPath: basePath)
    }
    
    func testSentryInstallationId() {
        let id = SentryInstallation.id(withCacheDirectoryPath: basePath)
        XCTAssertEqual(id, SentryInstallation.id(withCacheDirectoryPath: basePath))
    }
    
    func testSentryInstallationIdsAreCached() {
        let id1 = SentryInstallation.id(withCacheDirectoryPath: basePath)
        XCTAssertEqual(id1, SentryInstallation.id(withCacheDirectoryPath: basePath))
        
        let id2 = SentryInstallation.id(withCacheDirectoryPath: "/var/tmp/SentryTests2")
        XCTAssertEqual(id2, SentryInstallation.id(withCacheDirectoryPath: "/var/tmp/SentryTests2"))
        
        let id3 = SentryInstallation.id(withCacheDirectoryPath: "/var/tmp/SentryTests3")
        XCTAssertEqual(id3, SentryInstallation.id(withCacheDirectoryPath: "/var/tmp/SentryTests3"))
        
        XCTAssertNotEqual(id1, SentryInstallation.id(withCacheDirectoryPath: "/var/tmp/SentryTests3"))
    }
    
    func testSentryInstallationIdFromFileCache() {
        let id1 = SentryInstallation.id(withCacheDirectoryPath: basePath)
        SentryInstallation.installationStringsByCacheDirectoryPaths.removeAllObjects()
        XCTAssertEqual(id1, SentryInstallation.id(withCacheDirectoryPath: basePath))
    }
}

