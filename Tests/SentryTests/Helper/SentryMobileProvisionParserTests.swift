@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

class SentryMobileProvisionParserTests: XCTestCase {
    
    // MARK: - Valid Content Tests
    
    func testInitWithValidEnterpriseContent() {
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
        
        let parser = SentryMobileProvisionParser(mobileProvisionContent: content)
        XCTAssertTrue(parser.provisionsAllDevices)
    }
    
    func testInitWithValidAdhocContent() {
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
        
        let parser = SentryMobileProvisionParser(mobileProvisionContent: content)
        XCTAssertFalse(parser.provisionsAllDevices)
    }
    
    func testInitWithContentWithoutProvisionsAllDevicesKey() {
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
        
        let parser = SentryMobileProvisionParser(mobileProvisionContent: content)
        XCTAssertFalse(parser.provisionsAllDevices) // Should default to false
    }
    
    func testInitWithExtraDataInMobileprovisionfile() {
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
        let parser = SentryMobileProvisionParser(mobileProvisionContent: content)
        XCTAssertTrue(parser.provisionsAllDevices)
    }
    
    // MARK: - Invalid Content Tests
    
    func testInitWithEmptyContent() {
        let parser = SentryMobileProvisionParser(mobileProvisionContent: "")
        XCTAssertFalse(parser.provisionsAllDevices) // Should default to false when parsing fails
    }
    
    func testInitWithMalformedPlistContent() {
        let content = """
        <plist>
        <dict>
            <key>ProvisionsAllDevices</key>
            <true/>
        </dict>
        """
        
        let parser = SentryMobileProvisionParser(mobileProvisionContent: content)
        XCTAssertFalse(parser.provisionsAllDevices) // Should default to false when parsing fails
    }
    
    func testInitWithMissingPlistTags() {
        let content = """
        <dict>
            <key>ProvisionsAllDevices</key>
            <true/>
        </dict>
        """
        
        let parser = SentryMobileProvisionParser(mobileProvisionContent: content)
        XCTAssertFalse(parser.provisionsAllDevices) // Should default to false when parsing fails
    }
    
    // MARK: - Edge Cases
    
    func testProvisionsAllDevicesWithNonBooleanValue() {
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
        
        let parser = SentryMobileProvisionParser(mobileProvisionContent: content)
        XCTAssertFalse(parser.provisionsAllDevices) // Should default to false when value is not boolean
    }
    
    func testProvisionsAllDevicesWithArrayValue() {
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
        
        let parser = SentryMobileProvisionParser(mobileProvisionContent: content)
        XCTAssertFalse(parser.provisionsAllDevices) // Should default to false when value is not boolean
    }
}
