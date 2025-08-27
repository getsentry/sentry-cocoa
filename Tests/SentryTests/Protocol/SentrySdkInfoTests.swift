@_spi(Private) @testable import Sentry
import SentryTestUtils
import XCTest

class SentrySdkInfoTests: XCTestCase {
    
    private let sdkName = "sentry.cocoa"

    private func cleanUp() {
        SentrySdkPackage.resetPackageManager()
        SentryExtraPackages.clear()
    }

    override func setUp() {
        cleanUp()
    }

    override func tearDown() {
        cleanUp()
    }

    func testWithPatchLevelSuffix() {
        let version = "50.10.20-beta1"
        let settings = SentrySDKSettings(dict: [:])
        let actual = SentrySdkInfo(
            name: sdkName,
            version: version,
            integrations: [],
            features: [],
            packages: [],
            settings: settings
        )

        XCTAssertEqual(sdkName, actual.name)
        XCTAssertEqual(version, actual.version)
    }
    
    func testWithAnyVersion() {
        let version = "anyVersion"
        let settings = SentrySDKSettings(dict: [:])
        let actual = SentrySdkInfo(
            name: sdkName,
            version: version,
            integrations: [],
            features: [],
            packages: [],
            settings: settings
        )
        
        XCTAssertEqual(sdkName, actual.name)
        XCTAssertEqual(version, actual.version)
    }
    
    func testSerialization() {
        let version = "5.2.0"
        let settings = SentrySDKSettings(dict: [:])
        let sdkInfo = SentrySdkInfo(
            name: sdkName,
            version: version,
            integrations: ["a"],
            features: ["b"],
            packages: [],
            settings: settings
        ).serialize()

        XCTAssertEqual(sdkName, sdkInfo["name"] as? String)
        XCTAssertEqual(version, sdkInfo["version"] as? String)
        XCTAssertEqual(["a"], sdkInfo["integrations"] as? [String])
        XCTAssertEqual(["b"], sdkInfo["features"] as? [String])
    }

    func testSerializationValidIntegrations() {
        let settings = SentrySDKSettings(dict: [:])
        let sdkInfo = SentrySdkInfo(
            name: "",
            version: "",
            integrations: ["a", "b"],
            features: [],
            packages: [],
            settings: settings
        ).serialize()

        XCTAssertEqual(["a", "b"], sdkInfo["integrations"] as? [String])
    }

    func testSerializationValidFeatures() {
        let settings = SentrySDKSettings(dict: [:])
        let sdkInfo = SentrySdkInfo(
            name: "",
            version: "",
            integrations: [],
            features: ["c", "d"],
            packages: [],
            settings: settings
        ).serialize()

        XCTAssertEqual(["c", "d"], sdkInfo["features"] as? [String])
    }

    func testSPM_packageInfo() throws {
        SentrySdkPackage.setPackageManager(0)
        let actual = SentrySdkInfo.global()
        let serialization = actual.serialize()

        let packages = try XCTUnwrap(serialization["packages"] as? [[String: Any]])
        XCTAssertEqual(1, packages.count)
        XCTAssertEqual(packages[0]["name"] as? String, "spm:getsentry/\(SentryMeta.sdkName)")
        XCTAssertEqual(packages[0]["version"] as? String, SentryMeta.versionString)
    }

    func testCarthage_packageInfo() throws {
        SentrySdkPackage.setPackageManager(2)
        let actual = SentrySdkInfo.global()
        let serialization = actual.serialize()

        let packages = try XCTUnwrap(serialization["packages"] as? [[String: Any]])
        XCTAssertEqual(1, packages.count)
        XCTAssertEqual(packages[0]["name"] as? String, "carthage:getsentry/\(SentryMeta.sdkName)")
        XCTAssertEqual(packages[0]["version"] as? String, SentryMeta.versionString)
    }

    func testcocoapods_packageInfo() throws {
        SentrySdkPackage.setPackageManager(1)
        let actual = SentrySdkInfo.global()
        let serialization = actual.serialize()

        let packages = try XCTUnwrap(serialization["packages"] as? [[String: Any]])
        XCTAssertEqual(1, packages.count)
        XCTAssertEqual(packages[0]["name"] as? String, "cocoapods:getsentry/\(SentryMeta.sdkName)")
        XCTAssertEqual(packages[0]["version"] as? String, SentryMeta.versionString)
    }

    func testNoPackageNames () {
        SentrySdkPackage.setPackageManager(3)
        let actual = SentrySdkInfo.global()

        XCTAssertEqual(0, actual.packages.count)
    }
    
    func testInitWithDict_SdkInfo() {
        let version = "10.3.1"
        let settings = SentrySDKSettings()
        settings.autoInferIP = true
        let expected = SentrySdkInfo(
            name: sdkName,
            version: version,
            integrations: ["a", "b"],
            features: ["c", "d"],
            packages: [
                ["name": "a", "version": "1"],
                ["name": "b", "version": "2"]
            ],
            settings: settings
        )

        let dict = [
            "name": sdkName,
            "version": version,
            "integrations": ["a", "b"],
            "features": ["c", "d"],
            "packages": [
                ["name": "a", "version": "1"],
                ["name": "b", "version": "2"]
            ],
            "settings": [
                "infer_ip": "auto"
            ]
        ] as [String: Any]

        XCTAssertEqual(expected, SentrySdkInfo(dict: dict))
    }

    func testInitWithDict_SdkInfo_RemovesDuplicates() {
        let version = "10.3.1"
        let settings = SentrySDKSettings(dict: ["infer_ip": "auto"])
        let expected = SentrySdkInfo(
            name: sdkName,
            version: version,
            integrations: ["b"],
            features: ["c"],
            packages: [
                ["name": "a", "version": "1"]
            ],
            settings: settings
        )

        let dict = [
            "name": sdkName,
            "version": version,
            "integrations": ["b", "b"],
            "features": ["c", "c"],
            "packages": [
                ["name": "a", "version": "1"],
                ["name": "a", "version": "1"]
            ],
            "settings": [
                "infer_ip": "auto"
            ]
        ] as [String: Any]

        XCTAssertEqual(expected, SentrySdkInfo(dict: dict))
    }

    func testInitWithDict_SdkInfo_IgnoresOrder() {
        let version = "10.3.1"
        let settings = SentrySDKSettings(dict: ["infer_ip": "never"])
        let expected = SentrySdkInfo(
            name: sdkName,
            version: version,
            integrations: ["a", "b"],
            features: ["c", "d"],
            packages: [
                ["name": "a", "version": "1"],
                ["name": "b", "version": "2"]
            ],
            settings: settings
        )

        let dict = [
            "name": sdkName,
            "version": version,
            "integrations": ["b", "a"],
            "features": ["d", "c"],
            "packages": [
                ["name": "b", "version": "2"],
                ["name": "a", "version": "1"]
            ]
            ,
            "settings": [
                "infer_ip": "never"
            ]
        ] as [String: Any]

        XCTAssertEqual(expected, SentrySdkInfo(dict: dict))
    }

    func testInitWithDict_AllNil() {
        let dict = [
            "name": nil,
            "version": nil,
            "integrations": nil,
            "features": nil,
            "packages": nil
        ] as [String: Any?]

        assertEmptySdkInfo(actual: SentrySdkInfo(dict: dict as [AnyHashable: Any]))
    }
    
    func testInitWithDict_WrongTypes() {
        let dict = [
            "name": 0,
            "version": 0,
            "integrations": 0,
            "features": 0,
            "packages": 0
        ]

        assertEmptySdkInfo(actual: SentrySdkInfo(dict: dict))
    }

    func testInitWithDict_WrongTypesInArrays() {
        let version = "10.3.1"
        let settings = SentrySDKSettings(dict: [:])
        settings.autoInferIP = false
        let expected = SentrySdkInfo(
            name: sdkName,
            version: version,
            integrations: ["a"],
            features: ["b"],
            packages: [
                ["name": "a", "version": "1"]
            ],
            settings: settings
        )

        let dict = [
            "name": sdkName,
            "version": version,
            "integrations":
                [
                    0,
                    [] as [Any],
                    "a",
                    [:] as [String: Any]
                ] as [Any],
            "features": [
                0,
                [] as [Any],
                "b",
                [:] as [String: Any]
            ] as [Any],
            "packages": [
                0,
                [] as [Any],
                "b",
                [:] as [String: Any],
                ["name": "a", "version": "1", "invalid": -1] as [String: Any]
            ] as [Any],
            "settings": [
                "infer_ip": "false"
            ]
        ] as [String: Any]

        XCTAssertEqual(expected, SentrySdkInfo(dict: dict))
    }

    func testInitWithDict_SdkInfoIsString() {
        let dict = ["sdk": ""]
        
        assertEmptySdkInfo(actual: SentrySdkInfo(dict: dict))
    }

    func testglobal() throws {
        SentrySDK.start(options: Options())
        let actual = SentrySdkInfo.global()
        XCTAssertEqual(actual.name, SentryMeta.sdkName)
        XCTAssertEqual(actual.version, SentryMeta.versionString)
        XCTAssertTrue(actual.integrations.count > 0)
        XCTAssertTrue(actual.features.count > 0)
    }
    
    func testFromGlobalsWithExtraPackage() throws {
        let extraPackage = ["name": "test-package", "version": "1.0.0"]
        SentryExtraPackages.addPackageName(extraPackage["name"]!, version: extraPackage["version"]!)

        let actual = SentrySdkInfo.global()
        XCTAssertEqual(actual.packages.count, 1)
        XCTAssertTrue(actual.packages.contains(extraPackage))
    }
    
    func testFromGlobalsWithExtraPackageAndPackageManager() throws {
        let extraPackage = ["name": "test-package", "version": "1.0.0"]
        SentryExtraPackages.addPackageName(extraPackage["name"]!, version: extraPackage["version"]!)
        SentrySdkPackage.setPackageManager(1)

        let actual = SentrySdkInfo.global()
        XCTAssertEqual(actual.packages.count, 2)
        XCTAssertTrue(actual.packages.contains(extraPackage))
        XCTAssertTrue(actual.packages.contains(["name": "cocoapods:getsentry/\(SentryMeta.sdkName)", "version": SentryMeta.versionString]))
    }

    func testSerializationIncludesSettings() {
        let version = "5.2.0"
        let settings = SentrySDKSettings(dict: ["infer_ip": "auto"])
        let sdkInfo = SentrySdkInfo(
            name: sdkName,
            version: version,
            integrations: ["a"],
            features: ["b"],
            packages: [],
            settings: settings
        ).serialize()

        XCTAssertEqual(sdkName, sdkInfo["name"] as? String)
        XCTAssertEqual(version, sdkInfo["version"] as? String)
        XCTAssertEqual(["a"], sdkInfo["integrations"] as? [String])
        XCTAssertEqual(["b"], sdkInfo["features"] as? [String])
        
        // Test that settings are included in serialization
        let serializedSettings = sdkInfo["settings"] as? [String: Any]
        XCTAssertNotNil(serializedSettings)
        XCTAssertEqual("auto", serializedSettings?["infer_ip"] as? String)
    }

    func testInitWithDict_IncludesSettings() {
        let version = "10.3.1"
        let dict = [
            "name": sdkName,
            "version": version,
            "integrations": ["a", "b"],
            "features": ["c", "d"],
            "packages": [
                ["name": "a", "version": "1"],
                ["name": "b", "version": "2"]
            ],
            "settings": [
                "infer_ip": "auto"
            ]
        ] as [String: Any]

        let actual = SentrySdkInfo(dict: dict)
        
        XCTAssertEqual(sdkName, actual.name)
        XCTAssertEqual(version, actual.version)
        XCTAssertEqual(["a", "b"], actual.integrations)
        XCTAssertEqual(["c", "d"], actual.features)
        XCTAssertEqual(2, actual.packages.count)
        
        // Test that settings are properly initialized
        XCTAssertTrue(actual.settings.autoInferIP)
    }

    func testInitWithDict_SettingsNil_DefaultsToEmptySettings() {
        let dict = [
            "name": sdkName,
            "version": "1.0.0",
            "settings": nil
        ] as [String: Any?]

        let actual = SentrySdkInfo(dict: dict as [AnyHashable: Any])
        
        XCTAssertNotNil(actual.settings)
        XCTAssertFalse(actual.settings.autoInferIP)
    }

    func testInitWithDict_SettingsMissing_DefaultsToEmptySettings() {
        let dict = [
            "name": sdkName,
            "version": "1.0.0"
        ] as [String: Any]

        let actual = SentrySdkInfo(dict: dict)
        
        XCTAssertNotNil(actual.settings)
        XCTAssertFalse(actual.settings.autoInferIP)
    }

    func testInitWithDict_SettingsWrongType_DefaultsToEmptySettings() {
        let dict = [
            "name": sdkName,
            "version": "1.0.0",
            "settings": "not_a_dict"
        ] as [String: Any]

        let actual = SentrySdkInfo(dict: dict)
        
        XCTAssertNotNil(actual.settings)
        XCTAssertFalse(actual.settings.autoInferIP)
    }

    func testEquality_IncludesSettings() {
        let settings1 = SentrySDKSettings(dict: ["infer_ip": "auto"])
        let settings2 = SentrySDKSettings(dict: ["infer_ip": "never"])
        
        let sdkInfo1 = SentrySdkInfo(
            name: sdkName,
            version: "1.0.0",
            integrations: [],
            features: [],
            packages: [],
            settings: settings1
        )
        
        let sdkInfo2 = SentrySdkInfo(
            name: sdkName,
            version: "1.0.0",
            integrations: [],
            features: [],
            packages: [],
            settings: settings2
        )
        
        // Should not be equal when settings differ
        XCTAssertNotEqual(sdkInfo1, sdkInfo2)
        
        let sdkInfo3 = SentrySdkInfo(
            name: sdkName,
            version: "1.0.0",
            integrations: [],
            features: [],
            packages: [],
            settings: settings1
        )
        
        // Should be equal when settings are the same
        XCTAssertEqual(sdkInfo1, sdkInfo3)
    }

    private func assertEmptySdkInfo(actual: SentrySdkInfo) {
        XCTAssertEqual(SentrySdkInfo(
            name: "",
            version: "",
            integrations: [],
            features: [],
            packages: [],
            settings: SentrySDKSettings(dict: [:])
        ), actual)
    }
}
