// swiftlint:disable missing_docs
import Foundation

@_spi(Private) @objc public class SentryEnvelopeItemHeader: NSObject, SentrySerializable {

    /**
     * The type of the envelope item.
     */
    @objc public let type: String
    @objc public let length: UInt
    @objc public let filename: String?
    @objc public let contentType: String?
    @objc public let itemCount: NSNumber?

    /**
     * Some envelopes need to report the platform name for enhanced rate limiting functionality in
     * relay.
     */
    @objc public var platform: String?

    @objc public init(type: String, length: UInt) {
        self.type = type
        self.length = length
        self.filename = nil
        self.contentType = nil
        self.itemCount = nil
        super.init()
    }

    @objc public init(type: String, length: UInt, contentType: String?) {
        self.type = type
        self.length = length
        self.filename = nil
        self.contentType = contentType
        self.itemCount = nil
        super.init()
    }

    @objc public init(type: String, length: UInt, filename: String?, contentType: String?) {
        self.type = type
        self.length = length
        self.filename = filename
        self.contentType = contentType
        self.itemCount = nil
        super.init()
    }

    @objc public init(type: String, length: UInt, contentType: String?, itemCount: NSNumber?) {
        self.type = type
        self.length = length
        self.filename = nil
        self.contentType = contentType
        self.itemCount = itemCount
        super.init()
    }

    @objc public func serialize() -> [String: Any] {
        var target = [String: Any]()

        target["type"] = type
        target["filename"] = filename
        target["content_type"] = contentType
        target["platform"] = platform
        target["item_count"] = itemCount
        target["length"] = NSNumber(value: length)

        return target
    }
}
// swiftlint:enable missing_docs
