import XCTest

class SentrySdkInterfaceTests: XCTestCase {
    
    private let sdkName = "sentry.cocoa"
    
    func testWithPatchLevelSuffix() {
        let version = "50.10.20-beta1"
        let actual = SentrySdkInterface(name: sdkName, andVersion: version)
        
        XCTAssertEqual(sdkName, actual.name)
        XCTAssertEqual(version, actual.version)
    }
    
    func testWithAnyVersion() {
        let version = "anyVersion"
        let actual = SentrySdkInterface(name: sdkName, andVersion: version)
        
        XCTAssertEqual(sdkName, actual.name)
        XCTAssertEqual(version, actual.version)
    }
    
    func testSerialization() {
        let version = "5.2.0"
        let actual = SentrySdkInterface(name: sdkName, andVersion: version).serialize()
        
        if let sdkInterface = actual["sdk"] as? [String: Any] {
            XCTAssertEqual(2, sdkInterface.count)
            XCTAssertEqual(sdkName, sdkInterface["name"] as? String)
            XCTAssertEqual(version, sdkInterface["version"] as? String)
        } else {
            XCTFail("Serialization of SdkInterface doesn't contain sdk")
        }
    }
    
    func testInitWithDict_SdkInterface() {
        let version = "10.3.1"
        let expected = SentrySdkInterface(name: sdkName, andVersion: version)
        
        let dict = ["sdk": [ "name": sdkName, "version": version]]
        
        XCTAssertEqual(expected, SentrySdkInterface(dict: dict))
    }
    
    func testInitWithDict_AllNil() {
        let dict = ["sdk": [ "name": nil, "version": nil]]
        
        assertEmptySdkInterface(actual: SentrySdkInterface(dict: dict))
    }
    
    func testInitWithDict_WrongTypes() {
        let dict = ["sdk": [ "name": 0, "version": 0]]
        
        assertEmptySdkInterface(actual: SentrySdkInterface(dict: dict))
    }
    
    func testInitWithDict_SdkInterfaceIsString() {
        let dict = ["sdk": ""]
        
        assertEmptySdkInterface(actual: SentrySdkInterface(dict: dict))
    }
    
    private func assertEmptySdkInterface(actual: SentrySdkInterface) {
        XCTAssertEqual(SentrySdkInterface(name: "", andVersion: ""), actual)
    }
}
