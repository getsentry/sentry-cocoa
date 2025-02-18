import Foundation

@objcMembers @objc(SentrySpanKey)
class SentrySpanKey: NSObject {
    /// Used to set the number of bytes processed in a file span operation
    static let fileSize = "file.size"

    /// Used to set the path of the file in a file span operation
    static let filePath = "file.path"
}
