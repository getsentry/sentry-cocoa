@_spi(Private) @testable import Sentry
import XCTest

final class SentryCrashWrapperTests: XCTestCase {
    
    private var crashWrapper: SentryCrashWrapper!
    private var scope: Scope!
    
    override func setUp() {
        super.setUp()
        crashWrapper = SentryCrashWrapper(processInfoWrapper: ProcessInfo.processInfo,
            systemInfo: [
            "osVersion": "23A344",
            "kernelVersion": "23.0.0",
            "isJailbroken": false,
            "systemName": "iOS",
            "cpuArchitecture": "arm64",
            "machine": "iPhone14,2",
            "model": "iPhone 13 Pro",
            "freeMemorySize": UInt64(1_073_741_824), // 1 GB
            "usableMemorySize": UInt64(4_294_967_296), // 4 GB
            "memorySize": UInt64(6_442_450_944), // 6 GB
            "appStartTime": "2023-01-01T12:00:00Z",
            "deviceAppHash": "abc123",
            "appID": "12345",
            "buildType": "debug",
            "CFBundleIdentifier": "io.sentry.crashTest",
            "CFBundleName": "CrashSentry",
            "CFBundleVersion": "201702072010",
            "CFBundleShortVersionString": "1.4.1"
        ])
        scope = Scope()
        
#if (os(iOS) || os(tvOS) || (swift(>=5.9) && os(visionOS))) && !targetEnvironment(macCatalyst)
        // Ensure DeviceWrapper info is initialized
        // This is done at SentrySDKInteral, but during tests that might not be the case
        Dependencies.uiDeviceWrapper.start()
#endif
    }
    
    override func tearDown() {
        crashWrapper = nil
        scope = nil
        super.tearDown()
    }
    
    func testEnrichScope_WithSystemInfo_SetsOSContext() throws {
        crashWrapper.enrichScope(scope)
        
        let osContext = try XCTUnwrap(scope.contextDictionary["os"] as? [String: Any])
        XCTAssertNotNil(osContext["name"])
        
#if os(macOS) || targetEnvironment(macCatalyst)
        let version = ProcessInfo.processInfo.operatingSystemVersion
        let expectedVersion = "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
        XCTAssertEqual(osContext["version"] as? String, expectedVersion)
#else
        let expectedVersion = try XCTUnwrap(Dependencies.uiDeviceWrapper.getSystemVersion())
        XCTAssertFalse(expectedVersion.isEmpty)
        XCTAssertEqual(osContext["version"] as? String, expectedVersion)
#endif
        
        XCTAssertEqual(osContext["build"] as? String, "23A344")
        XCTAssertEqual(osContext["kernel_version"] as? String, "23.0.0")
        XCTAssertEqual(osContext["rooted"] as? Bool, false)
    }
    
    func testEnrichScope_WithSystemInfo_SetsDeviceContext() throws {
        crashWrapper.enrichScope(scope)
        
        let deviceContext = try XCTUnwrap(scope.contextDictionary["device"] as? [String: Any])
        XCTAssertEqual(deviceContext["arch"] as? String, "arm64")
        XCTAssertEqual(deviceContext["model"] as? String, "iPhone14,2")
        XCTAssertEqual(deviceContext["model_id"] as? String, "iPhone 13 Pro")
        XCTAssertEqual(deviceContext["free_memory"] as? UInt64, 1_073_741_824)
        XCTAssertEqual(deviceContext["usable_memory"] as? UInt64, 4_294_967_296)
        XCTAssertEqual(deviceContext["memory_size"] as? UInt64, 6_442_450_944)
        XCTAssertNotNil(deviceContext["locale"])
    }
    
    func testEnrichScope_WithSystemInfo_SetsAppContext() throws {
        crashWrapper.enrichScope(scope)
        
        let appContext = try XCTUnwrap(scope.contextDictionary["app"] as? [String: Any])
        XCTAssertEqual(appContext["app_start_time"] as? String, "2023-01-01T12:00:00Z")
        XCTAssertEqual(appContext["device_app_hash"] as? String, "abc123")
        XCTAssertEqual(appContext["app_id"] as? String, "12345")
        XCTAssertEqual(appContext["build_type"] as? String, "debug")
        
        // App info from Bundle should also be present
        let infoDict = Bundle.main.infoDictionary ?? [:]
        XCTAssertEqual(appContext["app_identifier"] as? String, infoDict["CFBundleIdentifier"] as? String)
        XCTAssertEqual(appContext["app_name"] as? String, infoDict["CFBundleName"] as? String)
        XCTAssertEqual(appContext["app_build"] as? String, infoDict["CFBundleVersion"] as? String)
        XCTAssertEqual(appContext["app_version"] as? String, infoDict["CFBundleShortVersionString"] as? String)
    }
    
    func testEnrichScope_DeviceContext_ContainsSimulatorFlag() throws {
        crashWrapper.enrichScope(scope)
        
        let deviceContext = try XCTUnwrap(scope.contextDictionary["device"] as? [String: Any])
        let simulator = deviceContext["simulator"] as? Bool
        
        XCTAssertNotNil(simulator)
        // Should be true for simulator builds, false for device builds
        #if targetEnvironment(simulator)
        XCTAssertTrue(simulator!)
        #else
        XCTAssertFalse(simulator!)
        #endif
    }
    
    func testEnrichScope_DeviceContext_ContainsDeviceFamily() throws {
        crashWrapper.enrichScope(scope)
        
        let deviceContext = try XCTUnwrap(scope.contextDictionary["device"] as? [String: Any])
        let family = deviceContext["family"] as? String
        
        #if targetEnvironment(macCatalyst)
        XCTAssertEqual(family, "macOS")
        #else
        XCTAssertEqual(family, "iOS")
        #endif
    }
    
    func testEnrichScope_RuntimeContext_MacCatalyst() throws {
        if #available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *) {
            #if targetEnvironment(macCatalyst)
            crashWrapper.enrichScope(scope)
            
            let runtimeContext = try XCTUnwrap(scope.contextDictionary["runtime"] as? [String: Any])
            XCTAssertEqual(runtimeContext["name"] as? String, "Mac Catalyst App")
            XCTAssertEqual(runtimeContext["raw_description"] as? String, "raw_description")
            #endif
        }
    }
}
