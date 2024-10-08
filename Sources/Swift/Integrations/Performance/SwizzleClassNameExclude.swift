import Foundation

@objcMembers
class SentrySwizzleClassNameExclude: NSObject {
    static func shouldExcludeClass(className: String, swizzleClassNameExcludes: Set<String>) -> Bool {
        for exclude in swizzleClassNameExcludes {
            if className.contains(exclude) {
                return true
            }
        }
        return false
    }
}
