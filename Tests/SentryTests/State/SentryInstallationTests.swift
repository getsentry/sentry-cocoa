@_spi(Private) import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

final class SentryInstallationTests: XCTestCase {

    private let basePath = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        try FileManager().createDirectory(atPath: basePath, withIntermediateDirectories: true)
    }
    
    override func tearDownWithError() throws {
        super.tearDown()
        SentryInstallation.clearCachedInstallationIds()
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: basePath) {
            try FileManager().removeItem(atPath: basePath)
        }
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
        SentryInstallation.clearCachedInstallationIds()
        XCTAssertEqual(id1, SentryInstallation.id(withCacheDirectoryPath: basePath))
    }
    
    func testCacheIDAsync_ExecutesOnBackgroundThread() {
        let dispatchQueue = TestSentryDispatchQueueWrapper()
        SentryDependencyContainer.sharedInstance().dispatchQueueWrapper = dispatchQueue
        
        SentryInstallation.cacheIDAsync(withCacheDirectoryPath: basePath)
        
        XCTAssertEqual(dispatchQueue.dispatchAsyncInvocations.count, 1)
    }
    
    func testCacheIDAsync_CashesID() throws {
        let dispatchQueue = TestSentryDispatchQueueWrapper()
        SentryDependencyContainer.sharedInstance().dispatchQueueWrapper = dispatchQueue
        
        SentryInstallation.cacheIDAsync(withCacheDirectoryPath: basePath)

        let nonCachedID = SentryInstallation.idNonCached(withCacheDirectoryPath: basePath)
        
        // We remove the file containing the installation ID, but the cached ID is still in memory
        try FileManager().removeItem(atPath: basePath)
        
        let nonCachedIDAfterDeletingFile = SentryInstallation.idNonCached(withCacheDirectoryPath: basePath)
        XCTAssertNil(nonCachedIDAfterDeletingFile)
        
        let cachedID = SentryInstallation.id(withCacheDirectoryPath: basePath)
        
        XCTAssertEqual(cachedID, nonCachedID)

    }
    
    func testCachedIDIsNilWhenNoInstallationIsFound() {
        let cachedID = SentryInstallation.cachedId(withCacheDirectoryPath: basePath)
        XCTAssertNil(cachedID)
    }
    
    func testCachedID_returnsActuallyCachedId() {
        let id1 = SentryInstallation.id(withCacheDirectoryPath: basePath)
        
        let cachedID = SentryInstallation.cachedId(withCacheDirectoryPath: basePath)
        
        XCTAssertEqual(id1, cachedID)
    }
}
