import XCTest

class SentryTransportInitializerTests: XCTestCase {
    
    private var fileManager: SentryFileManager!
    
    override func setUp() {
        do {
            let dsn = try SentryDsn(string: TestConstants.dsn as String)
            fileManager = try SentryFileManager.init(dsn: dsn)
        } catch {
            XCTFail("SentryDsn could not be created")
        }
        
    }

    func testDefault() throws {
        let options =  try Options(dict: ["dsn": TestConstants.dsn])
        
        let result = TransportInitializer.initTransport(options, sentryFileManager: fileManager)
        
        XCTAssertTrue( result.isKind(of: SentryHttpTransport.self))
    }
    
    func testCustom() throws {
        let transport = TestTransport()
        let options = try Options(dict: ["dsn": TestConstants.dsn, "transport": transport])
        let result = TransportInitializer.initTransport(options, sentryFileManager: fileManager)
        
        XCTAssertTrue( result.isKind(of: TestTransport.self))
    }
}
