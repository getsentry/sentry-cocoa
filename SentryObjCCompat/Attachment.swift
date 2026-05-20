@_implementationOnly import Sentry
import Foundation

/// File or in-memory data sent alongside an event.
@objc(SOCSentryAttachment)
public final class Attachment: NSObject {
    internal let wrapped: Sentry.Attachment

    internal init(_ wrapped: Sentry.Attachment) {
        self.wrapped = wrapped
        super.init()
    }

    @objc public init(data: Data, filename: String) {
        self.wrapped = Sentry.Attachment(data: data, filename: filename)
        super.init()
    }

    @objc public init(data: Data, filename: String, contentType: String?) {
        self.wrapped = Sentry.Attachment(data: data, filename: filename, contentType: contentType)
        super.init()
    }

    @objc public init(path: String) {
        self.wrapped = Sentry.Attachment(path: path)
        super.init()
    }

    @objc public init(path: String, filename: String) {
        self.wrapped = Sentry.Attachment(path: path, filename: filename)
        super.init()
    }

    @objc public init(path: String, filename: String, contentType: String?) {
        self.wrapped = Sentry.Attachment(path: path, filename: filename, contentType: contentType)
        super.init()
    }

    @objc public init(
        data: Data,
        filename: String,
        contentType: String?,
        attachmentType: SentryAttachmentType
    ) {
        self.wrapped = Sentry.Attachment(
            data: data,
            filename: filename,
            contentType: contentType,
            attachmentType: attachmentType.underlying
        )
        super.init()
    }

    @objc public init(
        path: String,
        filename: String,
        contentType: String?,
        attachmentType: SentryAttachmentType
    ) {
        self.wrapped = Sentry.Attachment(
            path: path,
            filename: filename,
            contentType: contentType,
            attachmentType: attachmentType.underlying
        )
        super.init()
    }

    @objc public var data: Data? { wrapped.data }
    @objc public var path: String? { wrapped.path }
    @objc public var filename: String { wrapped.filename }
    @objc public var contentType: String? { wrapped.contentType }
    @objc public var attachmentType: SentryAttachmentType {
        SentryAttachmentType(wrapped.attachmentType)
    }
}
