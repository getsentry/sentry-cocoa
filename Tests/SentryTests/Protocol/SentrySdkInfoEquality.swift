import Foundation

extension SentrySdkInfo {
    open override func isEqual(_ object: Any?) -> Bool {
        if let other = object as? SentrySdkInfo {
            return sdkName == other.sdkName &&
                versionMajor == other.versionMajor &&
                versionMinor == other.versionMinor &&
                versionPatchLevel == other.versionPatchLevel
        } else {
            return false
        }
    }
}
