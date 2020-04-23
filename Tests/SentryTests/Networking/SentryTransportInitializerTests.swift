@testable import Sentry
import XCTest

class SentryTransportInitializerTests: XCTestCase {
    
    private var fileManager: SentryFileManager!
    
    override func setUp() {
        do {
            fileManager = try SentryFileManager.init(dsn: TestConstants.dsn)
        } catch {
            XCTFail("SentryDsn could not be created")
        }
    }

    func testDefault() throws {
        let options =  try Options(dict: ["dsn": TestConstants.dsnAsString])
        
        let result = TransportInitializer.initTransport(options, sentryFileManager: fileManager)
        
        XCTAssertTrue(result.isKind(of: SentryHttpTransport.self))
    }
    
    func testCustom() throws {
        let transport = TestTransport()
        let options = try Options(dict: ["dsn": TestConstants.dsnAsString, "transport": transport])
        let result = TransportInitializer.initTransport(options, sentryFileManager: fileManager)
        
        XCTAssertTrue( result.isKind(of: TestTransport.self))
    }
}
