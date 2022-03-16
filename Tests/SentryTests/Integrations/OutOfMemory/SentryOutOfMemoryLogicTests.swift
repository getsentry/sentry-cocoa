import XCTest

class SentryOutOfMemoryLogicTests: XCTestCase {

    private static let dsnAsString = TestConstants.dsnAsString(username: "SentryOutOfMemoryLogicTests")
    private static let dsn = TestConstants.dsn(username: "SentryOutOfMemoryLogicTests")
    
    private class Fixture {
        
        let options: Options
        let client: TestClient!
        let crashWrapper: TestSentryCrashWrapper
        let fileManager: SentryFileManager
        let currentDate = TestCurrentDateProvider()
        let sysctl = TestSysctl()
        let dispatchQueue = TestSentryDispatchQueueWrapper()
        
        init() {
            options = Options()
            options.dsn = SentryOutOfMemoryLogicTests.dsnAsString
            options.releaseName = TestData.appState.releaseName
            
            client = TestClient(options: options)
            
            crashWrapper = TestSentryCrashWrapper.sharedInstance()
            
            fileManager = try! SentryFileManager(options: options, andCurrentDateProvider: currentDate)
        }
        
        func getSut() -> SentryOutOfMemoryLogic {
            let appStateManager = SentryAppStateManager(options: options, crashWrapper: crashWrapper, fileManager: fileManager, currentDateProvider: currentDate, sysctl: sysctl)
            return SentryOutOfMemoryLogic(options: options, crashAdapter: crashWrapper, appStateManager: appStateManager)
        }
    }
    
    private var fixture: Fixture!
    private var sut: SentryOutOfMemoryLogic!
    
    override func setUp() {
        super.setUp()
        
        fixture = Fixture()
        sut = fixture.getSut()
    }
    
    override func tearDown() {
        super.tearDown()
        fixture.fileManager.deleteAllFolders()
    }

    func testExample() throws {

    }

}
