internal import _SentryPrivate
// swiftlint:disable missing_docs
import Foundation

@_spi(Private) @objc public final class SentryEnvelopeAttachmentHeader: SentryEnvelopeItemHeader {

    @objc public let attachmentType: SentryAttachmentType

    @objc public init(type: String, length: UInt, filename: String?, contentType: String?, attachmentType: SentryAttachmentType) {
        self.attachmentType = attachmentType
        super.init(type: type, length: length, filename: filename, contentType: contentType)
    }

    @objc public override init(type: String, length: UInt) {
        self.attachmentType = .eventAttachment
        super.init(type: type, length: length)
    }

    @objc public override func serialize() -> [String: Any] {
        var result = super.serialize()
        result["attachment_type"] = nameForSentryAttachmentType(attachmentType)
        return result
    }
}
// swiftlint:enable missing_docs
