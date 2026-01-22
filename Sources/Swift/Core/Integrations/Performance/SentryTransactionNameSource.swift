import Foundation

/// Describes the source of the transaction name.
///
/// This is used to indicate how the transaction name was determined, which affects
/// how Sentry processes and groups transactions.
@objc
public enum SentryTransactionNameSource: Int {
    /// The name was set manually by the user.
    @objc(kSentryTransactionNameSourceCustom)
    case custom = 0
    
    /// The name was derived from the request URL.
    @objc(kSentryTransactionNameSourceUrl)
    case url
    
    /// The name was derived from a routing framework.
    @objc(kSentryTransactionNameSourceRoute)
    case route
    
    /// The name was derived from a UI view or screen.
    @objc(kSentryTransactionNameSourceView)
    case view
    
    /// The name was derived from a UI component.
    @objc(kSentryTransactionNameSourceComponent)
    case component
    
    /// The name was derived from a background task.
    @objc(kSentryTransactionNameSourceTask)
    case sourceTask
}
