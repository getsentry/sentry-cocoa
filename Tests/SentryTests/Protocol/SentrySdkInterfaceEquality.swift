import Foundation

extension SentrySdkInfo {
    open override func isEqual(_ object: Any?) -> Bool {
        if let other = object as? SentrySdkInfo {
            return name == other.name &&
                version == other.version
        } else {
            return false
        }
    }
}
