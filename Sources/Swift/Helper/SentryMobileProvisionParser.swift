@objc @_spi(Private)
public class SentryMobileProvisionParser: NSObject {
    var profileContent: [String: Any] = [:]
    
    @objc @_spi(Private) public var provisionsAllDevices: Bool {
        return profileContent["ProvisionsAllDevices"] as? Bool ?? false
    }
    
    @objc @_spi(Private)
    public init(path: String) {
        super.init()
        
        parseProfileFromPath(path)
    }
    
    // Only used for testing
#if DEBUG || SENTRY_TEST || SENTRY_TEST_CI
    init(mobileProvisionContent: String) {
        super.init()
        
        parseProfileFromString(mobileProvisionContent)
    }
#endif
    
    private func parseProfileFromPath(_ path: String) {
        guard let fileData = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
            return
        }
        
        // The file is a CMS (PKCS#7) container with a plist embedded inside as text.
        // Convert to Latin-1 to preserve the bytes -> string even if not UTF-8.
        guard let payload = String(data: fileData, encoding: .isoLatin1) else { return }

        parseProfileFromString(payload)
    }
    
    private func parseProfileFromString(_ payload: String) {
        guard let startRange = payload.range(of: "<plist"),
              let endRange = payload.range(of: "</plist>") else {
            return
        }
        
        let plistRange = startRange.lowerBound ..< payload.index(endRange.upperBound, offsetBy: 0)
        let plistString = String(payload[plistRange])
        guard let plistData = plistString.data(using: .utf8) else { return }

        var format = PropertyListSerialization.PropertyListFormat.xml
        
#if swift(>=5.9) && os(visionOS)
        let options = 0
#else
        let options: PropertyListSerialization.ReadOptions = []
#endif
        
        guard let obj = try? PropertyListSerialization.propertyList(from: plistData,
                                                                    options: options,
                                                                    format: &format),
              let dict = obj as? [String: Any] else {
            return
        }
        profileContent = dict
    }
}
