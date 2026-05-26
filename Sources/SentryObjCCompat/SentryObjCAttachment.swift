// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
internal import SentrySwift
#else
internal import Sentry
#endif
import Foundation

@objc(SentryObjCAttachment) public final class SentryObjCAttachment: NSObject {
    internal let wrapped: Attachment

    internal init(_ wrapped: Attachment) {
        self.wrapped = wrapped
    }

    @objc public init(data: Data, filename: String) {
        self.wrapped = Attachment(data: data, filename: filename)
    }

    @objc public init(data: Data, filename: String, contentType: String?) {
        self.wrapped = Attachment(data: data, filename: filename, contentType: contentType)
    }

    @objc public init(path: String) {
        self.wrapped = Attachment(path: path)
    }

    @objc public init(path: String, filename: String) {
        self.wrapped = Attachment(path: path, filename: filename)
    }

    @objc public init(path: String, filename: String, contentType: String?) {
        self.wrapped = Attachment(path: path, filename: filename, contentType: contentType)
    }

    @objc public init(data: Data, filename: String, contentType: String?, attachmentType: SentryObjCAttachmentType) {
        self.wrapped = Attachment(data: data, filename: filename, contentType: contentType, attachmentType: attachmentType.underlying)
    }

    @objc public init(path: String, filename: String, contentType: String?, attachmentType: SentryObjCAttachmentType) {
        self.wrapped = Attachment(path: path, filename: filename, contentType: contentType, attachmentType: attachmentType.underlying)
    }

    @objc public var data: Data? {
        wrapped.data
    }

    @objc public var path: String? {
        wrapped.path
    }

    @objc public var filename: String {
        wrapped.filename
    }

    @objc public var contentType: String? {
        wrapped.contentType
    }

    @objc public var attachmentType: SentryObjCAttachmentType {
        SentryObjCAttachmentType(wrapped.attachmentType)
    }
}

// swiftlint:enable missing_docs
