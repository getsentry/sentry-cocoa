@_implementationOnly import Sentry
import Foundation

/// Status of a span/transaction.
///
/// Raw values match `Sentry.SentrySpanStatus`.
@objc(SOCSentrySpanStatus)
public enum SentrySpanStatus: UInt {
    case undefined = 0
    case ok = 1
    case deadlineExceeded = 2
    case unauthenticated = 3
    case permissionDenied = 4
    case notFound = 5
    case resourceExhausted = 6
    case invalidArgument = 7
    case unimplemented = 8
    case unavailable = 9
    case internalError = 10
    case unknownError = 11
    case cancelled = 12
    case alreadyExists = 13
    case failedPrecondition = 14
    case aborted = 15
    case outOfRange = 16
    case dataLoss = 17
}

extension SentrySpanStatus {
    init(_ underlying: Sentry.SentrySpanStatus) {
        self = SentrySpanStatus(rawValue: underlying.rawValue) ?? .undefined
    }

    var underlying: Sentry.SentrySpanStatus {
        Sentry.SentrySpanStatus(rawValue: rawValue) ?? .undefined
    }
}

/// Trace sample decision.
///
/// Raw values match `Sentry.SentrySampleDecision`.
@objc(SOCSentrySampleDecision)
public enum SentrySampleDecision: UInt {
    case undecided = 0
    case yes = 1
    case no = 2
}

extension SentrySampleDecision {
    init(_ underlying: Sentry.SentrySampleDecision) {
        self = SentrySampleDecision(rawValue: underlying.rawValue) ?? .undecided
    }

    var underlying: Sentry.SentrySampleDecision {
        Sentry.SentrySampleDecision(rawValue: rawValue) ?? .undecided
    }
}

/// Origin of a transaction name.
///
/// Raw values match `Sentry.SentryTransactionNameSource`.
@objc(SOCSentryTransactionNameSource)
public enum SentryTransactionNameSource: Int {
    case custom = 0
    case url = 1
    case route = 2
    case view = 3
    case component = 4
    case sourceTask = 5
}

extension SentryTransactionNameSource {
    init(_ underlying: Sentry.SentryTransactionNameSource) {
        self = SentryTransactionNameSource(rawValue: underlying.rawValue) ?? .custom
    }

    var underlying: Sentry.SentryTransactionNameSource {
        Sentry.SentryTransactionNameSource(rawValue: rawValue) ?? .custom
    }
}

/// Where a user-feedback submission originated.
///
/// Raw values match the nested `Sentry.SentryFeedback.SentryFeedbackSource` enum.
@objc(SOCSentryFeedbackSource)
public enum SentryFeedbackSource: Int {
    case widget = 0
    case custom = 1
}

extension SentryFeedbackSource {
    init(_ underlying: Sentry.SentryFeedback.SentryFeedbackSource) {
        self = SentryFeedbackSource(rawValue: underlying.rawValue) ?? .widget
    }

    var underlying: Sentry.SentryFeedback.SentryFeedbackSource {
        Sentry.SentryFeedback.SentryFeedbackSource(rawValue: rawValue) ?? .widget
    }
}

/// Attachment classification.
///
/// Raw values match `Sentry.SentryAttachmentType`.
@objc(SOCSentryAttachmentType)
public enum SentryAttachmentType: Int {
    case eventAttachment = 0
    case viewHierarchy = 1
}

extension SentryAttachmentType {
    init(_ underlying: Sentry.SentryAttachmentType) {
        self = SentryAttachmentType(rawValue: underlying.rawValue) ?? .eventAttachment
    }

    var underlying: Sentry.SentryAttachmentType {
        Sentry.SentryAttachmentType(rawValue: rawValue) ?? .eventAttachment
    }
}
