internal import _SentryPrivate
import Foundation

extension SentryTracer {
    /// The transaction context stored on this tracer.
    ///
    /// The Objective-C property is an untyped migration value so this header can stay in
    /// `_SentryPrivate`. Callers in this module read the typed context from here.
    var transactionContext: TransactionContext {
        guard let context = transactionContextObject as? TransactionContext else {
            SentrySDKLog.error("SentryTracer.transactionContext was not a TransactionContext.")
            return TransactionContext(name: "", operation: "")
        }
        return context
    }
}
