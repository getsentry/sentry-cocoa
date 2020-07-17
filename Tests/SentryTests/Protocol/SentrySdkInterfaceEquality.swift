import Foundation

extension SentrySdkInterface {
    open override func isEqual(_ object: Any?) -> Bool {
        if let other = object as? SentrySdkInterface {
            return name == other.name &&
                version == other.version
        } else {
            return false
        }
    }
}
