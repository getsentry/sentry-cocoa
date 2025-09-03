@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

class SentryMobileProvisionParserTests: XCTestCase {
    private func createFileAndAssert(_ content: String, at fileName: String = #function, assertBlock: ((String) throws -> Void)) throws {
        let tmpPath = FileManager.default.temporaryDirectory.path
        let path = "\(tmpPath)\(fileName).tmp"
        try content.write(toFile: path, atomically: true, encoding: .utf8)
        
        try assertBlock(path)
        
        try FileManager.default.removeItem(atPath: path)
    }
    
    // MARK: - Valid Content Tests
    
    func testInitWithValidEnterpriseContent() throws {
        let content = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>ProvisionsAllDevices</key>
            <true/>
            <key>AppIDName</key>
            <string>Enterprise App</string>
        </dict>
        </plist>
        """
        try createFileAndAssert(content) { path in
            let parser = SentryMobileProvisionParser(path)
            XCTAssertTrue(parser.mobileProvisionProfileProvisionsAllDevices)
        }
    }
    
    func testInitWithValidAdhocContent() throws {
        let content = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>ProvisionsAllDevices</key>
            <false/>
            <key>AppIDName</key>
            <string>Adhoc App</string>
            <ProvisionedDevices>
            </ProvisionedDevices>
        </dict>
        </plist>
        """
        
        try createFileAndAssert(content) { path in
            let parser = SentryMobileProvisionParser(path)
            XCTAssertFalse(parser.mobileProvisionProfileProvisionsAllDevices)
        }
    }
    
    func testInitWithContentWithoutProvisionsAllDevicesKey() throws {
        let content = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>AppIDName</key>
            <string>No Provisions All Devices Key</string>
            <ProvisionedDevices>
            </ProvisionedDevices>
        </dict>
        </plist>
        """
        
        try createFileAndAssert(content) { path in
            let parser = SentryMobileProvisionParser(path)
            XCTAssertFalse(parser.mobileProvisionProfileProvisionsAllDevices)
        }
    }
    
    func testInitWithExtraDataInMobileprovisionfile() throws {
        let content = """
        This is not a valid plist content
        <plist>
        <dict>
            <key>ProvisionsAllDevices</key>
            <true/>
        </dict>
        </plist>
        This isn't valid content either
        """
        
        // The parser scans for the plist inside the profile, so it should find it
        try createFileAndAssert(content) { path in
            let parser = SentryMobileProvisionParser(path)
            XCTAssertTrue(parser.mobileProvisionProfileProvisionsAllDevices)
        }
    }
    
    // MARK: - Invalid Content Tests
    
    func testInitWithEmptyContent() throws {
        try createFileAndAssert("") { path in
            let parser = SentryMobileProvisionParser(path)
            XCTAssertFalse(parser.mobileProvisionProfileProvisionsAllDevices) // Should default to false when parsing fails
        }
    }
    
    func testInitWithMalformedPlistContent() throws {
        let content = """
        <plist>
        <dict>
            <key>ProvisionsAllDevices</key>
            <true/>
        </dict>
        """
        
        try createFileAndAssert(content) { path in
            let parser = SentryMobileProvisionParser(path)
            XCTAssertFalse(parser.mobileProvisionProfileProvisionsAllDevices) // Should default to false when parsing fails
        }
    }
    
    func testInitWithMissingPlistTags() throws {
        let content = """
        <dict>
            <key>ProvisionsAllDevices</key>
            <true/>
        </dict>
        """
        
        try createFileAndAssert(content) { path in
            let parser = SentryMobileProvisionParser(path)
            XCTAssertFalse(parser.mobileProvisionProfileProvisionsAllDevices) // Should default to false when parsing fails
        }
    }
    
    // MARK: - Edge Cases
    
    func testProvisionsAllDevicesWithNonBooleanValue() throws {
        let content = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>ProvisionsAllDevices</key>
            <string>true</string>
        </dict>
        </plist>
        """
        
        try createFileAndAssert(content) { path in
            let parser = SentryMobileProvisionParser(path)
            XCTAssertFalse(parser.mobileProvisionProfileProvisionsAllDevices) // Should default to false when value is not boolean
        }
    }
    
    func testProvisionsAllDevicesWithArrayValue() throws {
        let content = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>ProvisionsAllDevices</key>
            <array>
                <string>true</string>
            </array>
        </dict>
        </plist>
        """
        
        try createFileAndAssert(content) { path in
            let parser = SentryMobileProvisionParser(path)
            XCTAssertFalse(parser.mobileProvisionProfileProvisionsAllDevices) // Should default to false when value is not boolean
        }
    }
    
    func testPathDoesNotExist() throws {
        let parser = SentryMobileProvisionParser("/randomPath.xml")
        XCTAssertFalse(parser.mobileProvisionProfileProvisionsAllDevices)
    }
    
    func testContentWithEmojiAndJapaneseCharacters() throws {
        // Create content with UTF-8 characters that cannot be represented in Latin-1
        // These include emojis, Chinese characters, and other Unicode characters
        let content = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>ProvisionsAllDevices</key>
            <true/>
            <key>AppIDName</key>
            <string>Test App with 中文 characters and 🚀 emojis</string>
        </dict>
        </plist>
        """
        
        try createFileAndAssert(content) { path in
            let parser = SentryMobileProvisionParser(path)
            // Should default to false when Latin-1 conversion fails and plist cannot be extracted
            XCTAssertTrue(parser.mobileProvisionProfileProvisionsAllDevices)
        }
    }
}
