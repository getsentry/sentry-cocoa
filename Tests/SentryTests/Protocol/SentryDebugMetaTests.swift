import XCTest

class SentryDebugMetaTests: XCTestCase {

    func testSerialize() {
        let debugMeta = TestData.debugMeta
        
        let actual = debugMeta.serialize()
        
        XCTAssertEqual(debugMeta.uuid, actual["uuid"] as? String)
        XCTAssertEqual(debugMeta.debugID, actual["debug_id"] as? String)
        XCTAssertEqual(debugMeta.type, actual["type"] as? String)
        XCTAssertEqual(debugMeta.imageAddress, actual["image_addr"] as? String)
        XCTAssertEqual(debugMeta.imageSize, actual["image_size"] as? NSNumber)
        XCTAssertEqual((debugMeta.name! as NSString).lastPathComponent, actual["name"] as? String)
        XCTAssertEqual(debugMeta.codeFile, actual["code_file"] as? String)
        XCTAssertEqual(debugMeta.imageVmAddress, actual["image_vmaddr"] as? String)
    }
}
