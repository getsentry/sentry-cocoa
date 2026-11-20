import Foundation

/// The kind of file stored on an attachment.
///
/// Downstream SDKs, such as sentry-godot, use this to tell attachment categories apart.
/// Most apps can leave it at the default, ``eventAttachment``.
///
/// See https://develop.sentry.dev/sdk/data-model/envelope-items/#attachment
@objc(SentryAttachmentType)
public enum SentryAttachmentType: Int, Sendable {
    /// Standard event attachment. This is the default for user-provided attachments.
    @objc(kSentryAttachmentTypeEventAttachment)
    case eventAttachment

    /// View hierarchy attachment. The SDK sets this when it captures view hierarchy data.
    @objc(kSentryAttachmentTypeViewHierarchy)
    case viewHierarchy

    /// Flame graph attachment containing aggregated call trees and symbolication inputs.
    @objc(kSentryAttachmentTypeFlamegraph)
    case flamegraph
}

private let sentryAttachmentTypeNameEventAttachment = "event.attachment"
private let sentryAttachmentTypeNameViewHierarchy = "event.view_hierarchy"
private let sentryAttachmentTypeNameFlamegraph = "event.flamegraph"

func nameForSentryAttachmentType(_ attachmentType: SentryAttachmentType) -> String {
    switch attachmentType {
    case .viewHierarchy:
        return sentryAttachmentTypeNameViewHierarchy
    case .flamegraph:
        return sentryAttachmentTypeNameFlamegraph
    case .eventAttachment:
        return sentryAttachmentTypeNameEventAttachment
    }
}

func typeForSentryAttachmentName(_ name: String?) -> SentryAttachmentType {
    if name == sentryAttachmentTypeNameViewHierarchy {
        return .viewHierarchy
    }
    if name == sentryAttachmentTypeNameFlamegraph {
        return .flamegraph
    }
    return .eventAttachment
}

/// A file stored alongside an event.
@objc(SentryAttachment)
open class Attachment: NSObject {
    /// The bytes of the attachment, or `nil` when the attachment is backed by a file path.
    @objc public let data: Data?

    /// The path of the file to upload, or `nil` when the attachment is backed by in-memory data.
    @objc public let path: String?

    /// The filename shown for this attachment in Sentry.
    @objc public let filename: String

    /// The content type of the attachment, or `nil` when the caller did not set one.
    @objc public let contentType: String?

    /// The kind of attachment.
    @objc public let attachmentType: SentryAttachmentType

    /// Creates an attachment from data. The content type is left unset.
    ///
    /// - Parameters:
    ///   - data: The bytes to upload.
    ///   - filename: The filename shown in Sentry.
    @objc public convenience init(data: Data, filename: String) {
        self.init(
            data: data,
            filename: filename,
            contentType: nil,
            attachmentType: .eventAttachment
        )
    }

    /// Creates an attachment from data.
    ///
    /// - Parameters:
    ///   - data: The bytes to upload.
    ///   - filename: The filename shown in Sentry.
    ///   - contentType: The content type, or `nil` to leave it unset.
    @objc public convenience init(data: Data, filename: String, contentType: String?) {
        self.init(
            data: data,
            filename: filename,
            contentType: contentType,
            attachmentType: .eventAttachment
        )
    }

    /// Creates an attachment from data.
    ///
    /// - Parameters:
    ///   - data: The bytes to upload.
    ///   - filename: The filename shown in Sentry.
    ///   - contentType: The content type, or `nil` to leave it unset.
    ///   - attachmentType: The kind of attachment. The default used by the other initializers is
    ///     ``SentryAttachmentType/eventAttachment``.
    @objc public init(
        data: Data,
        filename: String,
        contentType: String?,
        attachmentType: SentryAttachmentType
    ) {
        self.data = data
        path = nil
        self.filename = filename
        self.contentType = contentType
        self.attachmentType = attachmentType
        super.init()
    }

    /// Creates an attachment from a file path.
    ///
    /// The filename is the last path component. The file is read when the SDK captures an event
    /// or transaction, not when the attachment is created. The content type is left unset.
    ///
    /// - Parameter path: The file to upload.
    @objc public convenience init(path: String) {
        self.init(path: path, filename: (path as NSString).lastPathComponent)
    }

    /// Creates an attachment from a file path.
    ///
    /// The file is read when the SDK captures an event or transaction, not when the attachment is
    /// created. The content type is left unset.
    ///
    /// - Parameters:
    ///   - path: The file to upload.
    ///   - filename: The filename shown in Sentry.
    @objc public convenience init(path: String, filename: String) {
        self.init(path: path, filename: filename, contentType: nil, attachmentType: .eventAttachment)
    }

    /// Creates an attachment from a file path.
    ///
    /// The file is read when the SDK captures an event or transaction, not when the attachment is
    /// created.
    ///
    /// - Parameters:
    ///   - path: The file to upload.
    ///   - filename: The filename shown in Sentry.
    ///   - contentType: The content type, or `nil` to leave it unset.
    @objc public convenience init(path: String, filename: String, contentType: String?) {
        self.init(
            path: path,
            filename: filename,
            contentType: contentType,
            attachmentType: .eventAttachment
        )
    }

    /// Creates an attachment from a file path.
    ///
    /// The file is read when the SDK captures an event or transaction, not when the attachment is
    /// created.
    ///
    /// - Parameters:
    ///   - path: The file to upload.
    ///   - filename: The filename shown in Sentry.
    ///   - contentType: The content type, or `nil` to leave it unset.
    ///   - attachmentType: The kind of attachment. The default used by the other initializers is
    ///     ``SentryAttachmentType/eventAttachment``.
    @objc public init(
        path: String,
        filename: String,
        contentType: String?,
        attachmentType: SentryAttachmentType
    ) {
        data = nil
        self.path = path
        self.filename = filename
        self.contentType = contentType
        self.attachmentType = attachmentType
        super.init()
    }

    /// Unavailable. Use an initializer that supplies data or a file path.
    @available(*, unavailable)
    public override init() {
        fatalError("init() is unavailable")
    }
}
