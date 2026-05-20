internal import SentrySwift
import Foundation

/// File or in-memory data sent alongside an event.
@objc(SOCSentryAttachment)
public final class Attachment: NSObject {
    internal let wrapped: SentrySwift.Attachment

    internal init(_ wrapped: SentrySwift.Attachment) {
        self.wrapped = wrapped
        super.init()
    }

    @objc public init(data: Data, filename: String) {
        self.wrapped = SentrySwift.Attachment(data: data, filename: filename)
        super.init()
    }

    @objc public init(data: Data, filename: String, contentType: String?) {
        self.wrapped = SentrySwift.Attachment(data: data, filename: filename, contentType: contentType)
        super.init()
    }

    @objc public init(path: String) {
        self.wrapped = SentrySwift.Attachment(path: path)
        super.init()
    }

    @objc public init(path: String, filename: String) {
        self.wrapped = SentrySwift.Attachment(path: path, filename: filename)
        super.init()
    }

    @objc public init(path: String, filename: String, contentType: String?) {
        self.wrapped = SentrySwift.Attachment(path: path, filename: filename, contentType: contentType)
        super.init()
    }

    @objc public init(
        data: Data,
        filename: String,
        contentType: String?,
        attachmentType: SentryAttachmentType
    ) {
        self.wrapped = SentrySwift.Attachment(
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
        self.wrapped = SentrySwift.Attachment(
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
