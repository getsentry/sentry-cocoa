@testable import Sentry
import XCTest

class SentryDebugMetaTests: XCTestCase {
    
    private class Fixture {
        func getSut() -> DebugMeta {
            let debugMeta = DebugMeta()
            debugMeta.uuid = "uuid"
            debugMeta.type = "type"
            debugMeta.name = "name"
            debugMeta.imageSize = 100
            debugMeta.imageAddress = "imageAddress"
            debugMeta.imageVmAddress = "imageVmAddress"
            return debugMeta
        }
    }
    
    private var fixture: Fixture!
    
    override func setUp() {
        super.setUp()
        fixture = Fixture()
    }
    
    func testIsEqual_SameObject() {
        let debugMeta = DebugMeta()
        XCTAssertEqual(debugMeta, debugMeta)
    }
    
    func testIsEqual_DifferentClass() {
        XCTAssertFalse(DebugMeta().isEqual(SubClassedDebugMeta()))
    }
    
    func testIsEqual_AllNil() {
        XCTAssertEqual(DebugMeta(), DebugMeta())
    }
    
    func testIsEqual_AllFieldsEqual() {
        XCTAssertEqual(fixture.getSut(), fixture.getSut())
    }
    
    func testIsEqual_DifferentUUID() {
        testIsEqualWithDifferentField(configure: { debugMeta in
            debugMeta.uuid = ""
        })
    }
    
    func testIsEqual_DifferentType() {
        testIsEqualWithDifferentField(configure: { debugMeta in
            debugMeta.type = ""
        })
    }
    
    func testIsEqual_DifferentName() {
        testIsEqualWithDifferentField(configure: { debugMeta in
            debugMeta.name = ""
        })
    }
    
    func testIsEqual_DifferentImageSize() {
        testIsEqualWithDifferentField(configure: { debugMeta in
            debugMeta.imageSize = 99
        })
    }
    
    func testIsEqual_DifferentImageAddress() {
        testIsEqualWithDifferentField(configure: { debugMeta in
            debugMeta.imageAddress = ""
        })
    }
    
    func testIsEqual_DifferentImageVmAddress() {
        testIsEqualWithDifferentField(configure: { debugMeta in
            debugMeta.imageVmAddress = ""
        })
    }
    
    private func testIsEqualWithDifferentField(configure: (DebugMeta) -> Void) {
        let debugMeta = fixture.getSut()
        configure(debugMeta)
        XCTAssertNotEqual(debugMeta, fixture.getSut())
    }
    
    func testSameHashForEqualObjects() {
        XCTAssertEqual(fixture.getSut().hash, fixture.getSut().hash)
    }
    
    func testDifferentHashForDifferentObjects() {
        XCTAssertNotEqual(DebugMeta().hash, fixture.getSut().hash)
    }
    
    private class SubClassedDebugMeta: DebugMeta {
        
    }
    
}
