import XCTest

class SentrySdkInfoTests: XCTestCase {
    
    private let sdkName = "sentry.cocoa"
    
    func testWithPatchLevelSuffix() {
        let actual = SentrySdkInfo(sdkName: sdkName, andVersionString: "50.10.20-beta1")
        
        XCTAssertEqual(sdkName, actual.sdkName)
        XCTAssertEqual(50, actual.versionMajor)
        XCTAssertEqual(10, actual.versionMinor)
        XCTAssertEqual(20, actual.versionPatchLevel)
    }
    
    func testWithGarbagePatchLevelSuffix() {
        let actual = SentrySdkInfo(sdkName: sdkName, andVersionString: "50.10.20a101a")
        
        XCTAssertEqual(sdkName, actual.sdkName)
        XCTAssertEqual(50, actual.versionMajor)
        XCTAssertEqual(10, actual.versionMinor)
        XCTAssertEqual(20, actual.versionPatchLevel)
    }
    
    func testWithCharactersOnly() {
        let actual = SentrySdkInfo(sdkName: sdkName, andVersionString: "aa.aa.aa")
        
        XCTAssertNil(actual.versionMajor)
        XCTAssertNil(actual.versionMinor)
        XCTAssertNil(actual.versionPatchLevel)
    }
    
    func testWithDotsOnly() {
        let actual = SentrySdkInfo(sdkName: sdkName, andVersionString: "..")
        
        XCTAssertNil(actual.versionMajor)
        XCTAssertNil(actual.versionMinor)
        XCTAssertNil(actual.versionPatchLevel)
    }
    
    func testOnlyPatch() {
        let actual = SentrySdkInfo(sdkName: sdkName, andVersionString: "..201-1.20")
        
        XCTAssertNil(actual.versionMajor)
        XCTAssertNil(actual.versionMinor)
        XCTAssertEqual(201, actual.versionPatchLevel)
    }
    
    func testWithNoPatch() {
        let actual = SentrySdkInfo(sdkName: sdkName, andVersionString: "50.10")
        
        XCTAssertEqual(sdkName, actual.sdkName)
        XCTAssertEqual(50, actual.versionMajor)
        XCTAssertEqual(10, actual.versionMinor)
        XCTAssertNil(actual.versionPatchLevel)
    }
    
    func testWithMajorOnly() {
        let actual = SentrySdkInfo(sdkName: sdkName, andVersionString: "50")
        
        XCTAssertEqual(sdkName, actual.sdkName)
        XCTAssertEqual(50, actual.versionMajor)
        XCTAssertNil(actual.versionMinor)
        XCTAssertNil(actual.versionPatchLevel)
    }
    
    func testSdkNameEmptyAndVersionEmpty() {
        let actual = SentrySdkInfo(sdkName: "", andVersionString: "")
        
        XCTAssertEqual("", actual.sdkName)
        XCTAssertNil(actual.versionMajor)
        XCTAssertNil(actual.versionMinor)
        XCTAssertNil(actual.versionPatchLevel)
    }
    
    func testSerialization() {
        let actual = SentrySdkInfo(sdkName: sdkName, andVersionString: "5.2.0").serialize()
        
        if let sdkInfo = actual["sdk_info"] as? [String: Any] {
            XCTAssertEqual(4, sdkInfo.count)
            XCTAssertEqual(sdkName, sdkInfo["sdk_name"] as? String)
            XCTAssertEqual(5, sdkInfo["version_major"] as? Int)
            XCTAssertEqual(2, sdkInfo["version_minor"] as? Int)
            XCTAssertEqual(0, sdkInfo["version_patchlevel"] as? Int)
        } else {
            XCTFail("Serialization of SdkInfo doesn't contain sdk_info")
        }
    }
    
    func testInitWithDict_NoSdkInfo() {
        let expected = SentrySdkInfo(sdkName: "", andVersionString: "")
        let actual = SentrySdkInfo(dict: ["": ""])
        
        XCTAssertEqual(expected, actual)
    }
    
    func testInitWithDict_AllNil() {
        let dict = ["sdk_info":
            [ "sdk_name": nil,
              "version_major": nil,
              "version_minor": nil,
              "version_patchlevel": nil
            ]
        ]
        
        assertEmptySdkInfo(actual: SentrySdkInfo(dict: dict))
    }
    
    func testInitWithDict_WrongTypes() {
        let dict = ["sdk_info":
            [ "sdk_name": 0,
              "version_major": "",
              "version_minor": "",
              "version_patchlevel": ""
            ]
        ]
        
        assertEmptySdkInfo(actual: SentrySdkInfo(dict: dict))
    }
    
    func testInitWithDict_SdkInfoIsString() {
        let dict = ["sdk_info": ""]
        
        assertEmptySdkInfo(actual: SentrySdkInfo(dict: dict))
    }
    
    func testInitWithDict_SdkInfo() {
        let expected = SentrySdkInfo(sdkName: "cocoa", andVersionString: "10.3.1")
        
        let dict = ["sdk_info":
            [ "sdk_name": expected.sdkName ?? "",
              "version_major": expected.versionMajor ?? 0,
              "version_minor": expected.versionMinor ?? 0,
              "version_patchlevel": expected.versionPatchLevel ?? 0
            ]
        ]
        
        XCTAssertEqual(expected, SentrySdkInfo(dict: dict))
    }
    
    private func assertEmptySdkInfo(actual: SentrySdkInfo) {
        XCTAssertEqual(SentrySdkInfo(sdkName: "", andVersionString: ""),actual)
    }
}
