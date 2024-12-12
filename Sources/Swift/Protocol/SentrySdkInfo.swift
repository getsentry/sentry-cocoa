import Foundation

@objc
enum SentrySdkPackageManager: Int {
    case spm
    case cocoapods
    case carthage
    case unknown
}

@objcMembers
class SentrySdkInfo: NSObject, SentrySerializable {
    /**
     * This is required to identify the package manager used when installing sentry.
     */
#if SWIFT_PACKAGE
    static let PACKAGE_MANAGER: SentrySdkPackageManager = .spm
#elseif COCOAPODS
    static let PACKAGE_MANAGER: SentrySdkPackageManager = .cocoapods
#elseif CARTHAGE_YES
    // CARTHAGE is a xcodebuild build setting with value `YES`, we need to convert it into a compiler
    // definition to be able to use it.
    static let PACKAGE_MANAGER: SentrySdkPackageManager = .carthage
#else
    static let PACKAGE_MANAGER: SentrySdkPackageManager = .unknown
#endif

    static func getPackageName(_ packageManager: SentrySdkPackageManager, _ sdkName: String) -> String? {
        switch packageManager {
        case .spm:
            return "spm:getsentry/\(sdkName)"
        case .cocoapods:
            return "cocoapods:getsentry/\(sdkName)"
        case .carthage:
            return "carthage:getsentry/\(sdkName)"
        case .unknown:
            return nil
        }
    }

    let packageManager: SentrySdkPackageManager
    let name: String
    let version: String

    @objc(initWithName:andVersion:)
    init(name: String, version: String) {
        self.name = name
        self.version = version
        self.packageManager = SentrySdkInfo.PACKAGE_MANAGER
    }

#if TEST
    init(name: String, version: String, packageManager: SentrySdkPackageManager) {
        self.name = name
        self.version = version
        self.packageManager = packageManager
    }
#endif

    convenience init(dict: [String: Any]) {
        guard let sdkDict = dict["sdk"] as? [String: Any] else {
            self.init(name: "", version: "")
            return
        }

        self.init(name: sdkDict["name"] as? String ?? "", version: sdkDict["version"] as? String ?? "")
    }

    func serialize() -> [String: Any] {
        if let sdkPackageName = SentrySdkInfo.getPackageName(packageManager, name) {
            return [
                "sdk": [
                    "name": name,
                    "version": version,
                    "packages": [
                        "name": sdkPackageName,
                        "version": version
                    ]
                ] as [String: Any]
            ]
        } else {
            return [
                "sdk": [
                    "name": name,
                    "version": version
                ]
            ]
        }
    }

#if TEST
    override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? SentrySdkInfo else {
            return false
        }

        return self.name == other.name &&
        self.version == other.version &&
        self.packageManager == other.packageManager
    }
#endif

}
