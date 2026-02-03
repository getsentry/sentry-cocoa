import Foundation

/**
 Helper class to create test bundles with custom Info.plist files for testing.
 
 This class provides utilities to create temporary bundles that can be used in tests,
 allowing you to test code that depends on `Bundle.infoDictionary` without relying
 on the actual test bundle's Info.plist.
 
 ## Usage Examples
 
 ### Using the predefined TestInfoPlist.plist:
 ```swift
 let testBundle = TestBundle.createTestBundle()
 let wrapper = SentryInfoPlistWrapper(bundle: testBundle)
 ```
 
 ### Creating a custom bundle on-the-fly:
 ```swift
 let customInfo = [
     "CustomKey": "CustomValue",
     "EnableFeature": true
 ] as [String: Any]
 let testBundle = TestBundle.createBundle(withInfoDictionary: customInfo)
 ```
 
 ### Cleanup:
 ```swift
 TestBundle.cleanup(testBundle)
 ```
 
 ## Note
 The bundles created by this class are temporary and stored in the system's
 temporary directory. Always call `cleanup(_:)` in your test's `tearDown()` method.
 */
class TestBundle {
    
    /// Creates a temporary bundle with the test Info.plist
    /// - Returns: A Bundle configured with the test Info.plist, or nil if creation fails
    static func createTestBundle() -> Bundle? {
        guard let plistURL = locateTestInfoPlist() else {
            print("⚠️ TestInfoPlist.plist not found in bundle resources")
            return nil
        }
        return createBundleFromPlist(at: plistURL)
    }
    
    // MARK: - Private Helpers
    
    /// Locates the TestInfoPlist.plist file in the test bundle
    /// - Returns: URL to the plist file, or nil if not found
    private static func locateTestInfoPlist() -> URL? {
        let testBundle = Bundle(for: TestBundle.self)
        
        // Try with subdirectory first
        if let url = testBundle.url(forResource: "TestInfoPlist", withExtension: "plist", subdirectory: "Helper/InfoPlist") {
            return url
        }
        
        // Try without subdirectory (Xcode might flatten the structure)
        return testBundle.url(forResource: "TestInfoPlist", withExtension: "plist")
    }
    
    /// Creates a temporary bundle directory
    /// - Parameter name: The name of the bundle directory
    /// - Returns: URL to the created directory, or nil if creation fails
    private static func createTempBundleDirectory(name: String) -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent(name)
        
        do {
            try FileManager.default.createDirectory(
                at: tempDir,
                withIntermediateDirectories: true,
                attributes: nil
            )
            return tempDir
        } catch {
            print("⚠️ Failed to create bundle directory: \(error)")
            return nil
        }
    }
    
    /// Creates a Bundle from a URL
    /// - Parameter url: The URL of the bundle directory
    /// - Returns: A Bundle instance, or nil if creation fails
    private static func createBundle(at url: URL) -> Bundle? {
        guard let bundle = Bundle(url: url) else {
            print("⚠️ Failed to create Bundle from directory at: \(url.path)")
            return nil
        }
        return bundle
    }
    
    /// Creates a bundle by copying an existing Info.plist file
    /// - Parameter plistURL: URL to the Info.plist file to copy
    /// - Returns: A Bundle configured with the copied Info.plist, or nil if creation fails
    private static func createBundleFromPlist(at plistURL: URL) -> Bundle? {
        guard let tempDir = createTempBundleDirectory(name: "TestBundle.bundle") else {
            return nil
        }
        
        do {
            let destURL = tempDir.appendingPathComponent("Info.plist")
            try FileManager.default.copyItem(at: plistURL, to: destURL)
            return createBundle(at: tempDir)
        } catch {
            print("⚠️ Failed to copy Info.plist: \(error)")
            return nil
        }
    }
    
    /// Creates an in-memory bundle with a custom Info.plist dictionary
    /// - Parameter infoDictionary: The dictionary to use as Info.plist
    /// - Returns: A Bundle with the specified infoDictionary
    static func createBundle(withInfoDictionary infoDictionary: [String: Any]) -> Bundle? {
        guard let tempDir = createTempBundleDirectory(name: "TestBundle.bundle") else {
            return nil
        }
        
        do {
            let plistURL = tempDir.appendingPathComponent("Info.plist")
            let plistData = try PropertyListSerialization.data(
                fromPropertyList: infoDictionary,
                format: .xml,
                options: 0
            )
            try plistData.write(to: plistURL)
            return createBundle(at: tempDir)
        } catch {
            print("⚠️ Failed to create Info.plist: \(error)")
            return nil
        }
    }
    
    /// Cleans up a temporary test bundle
    /// - Parameter bundle: The bundle to clean up
    static func cleanup(_ bundle: Bundle?) throws {
        guard let bundle = bundle else {
            return
        }
        
        // Only delete if it's in the temp directory (safety check)
        if bundle.bundleURL.path.contains(FileManager.default.temporaryDirectory.path) {
            try FileManager.default.removeItem(at: bundle.bundleURL)
        }
    }
}
