import Foundation
@_implementationOnly import _SentryPrivate

@objc
protocol SentrySessionListener : NSObjectProtocol
{
    func sentrySessionEnded(_ session : SentrySession)
    func sentrySessionStarted(_ session : SentrySession)
}
