// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
internal import SentrySwift
#else
internal import Sentry
#endif

@objc public enum SentryObjCAttachmentType: Int {
    case eventAttachment = 0, viewHierarchy
}

extension SentryObjCAttachmentType {
    init(_ underlying: SentryAttachmentType) {
        self = SentryObjCAttachmentType(rawValue: underlying.rawValue) ?? .eventAttachment
    }
    var underlying: SentryAttachmentType {
        SentryAttachmentType(rawValue: rawValue) ?? .eventAttachment
    }
}

// swiftlint:enable missing_docs
