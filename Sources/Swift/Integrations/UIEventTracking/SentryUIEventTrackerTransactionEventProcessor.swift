internal import _SentryPrivate
import Foundation

#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK

/// Starts and manages UI event transactions for automatic user interaction tracing.
final class SentryUIEventTrackerTransactionEventProcessor {
    private let idleTimeout: TimeInterval
    private let activeTransactionsStorage = SentryMutex<[SentryTracer]>([])

    /// Creates a transaction mode with the idle timeout used for UI event transactions.
    init(idleTimeout: TimeInterval) {
        self.idleTimeout = idleTimeout
    }

#if SENTRY_TEST || SENTRY_TEST_CI
    var activeTransactions: [SentryTracer] {
        activeTransactionsStorage.withLock { $0 }
    }
#endif
}

extension SentryUIEventTrackerTransactionEventProcessor: SentryUIEventTracker.EventProcessor {
    /// Handles a tracked UI event by starting or updating an automatic transaction.
    func handleUIEvent(
        _ action: String,
        operation: String,
        accessibilityIdentifier: String?
    ) {
        let currentActiveTransaction = activeTransactionsStorage.withLock { $0.last }

        if currentActiveTransaction?.transactionContext.name == action {
            SentrySDKLog.debug("Dispatching idle timeout for transaction with span id \(currentActiveTransaction?.spanId.sentrySpanIdString ?? "nil")")
            currentActiveTransaction?.startIdleTimeout()
            return
        }

        currentActiveTransaction?.finish()
        if let currentActiveTransaction {
            SentrySDKLog.debug("Finished transaction \(currentActiveTransaction.transactionContext.name) (span ID \(currentActiveTransaction.spanId.sentrySpanIdString))")
        }

        let currentSpan = SentrySDKInternal.currentHub().scope.span
        let ongoingScreenLoadTransaction = currentSpan?.operation == SentrySpanOperationUiLoad
        let ongoingManualTransaction = currentSpan.map { span in
            span.operation != SentrySpanOperationUiLoad && !span.operation.contains(SentrySpanOperationUiAction)
        } ?? false
        if ongoingScreenLoadTransaction || ongoingManualTransaction {
            SentrySDKLog.debug("Not starting a new UI event transaction because there is already an ongoing transaction bound to the scope.")
            return
        }

        let transaction = startTransaction(action: action, operation: operation)
        if let accessibilityIdentifier {
            transaction.setTag(value: accessibilityIdentifier, key: "accessibilityIdentifier")
        }
        trackTransaction(transaction)
    }

    private func startTransaction(action: String, operation: String) -> SentryTracer {
        let context = TransactionContext(
            name: action,
            rawNameSource: SentryTransactionNameSource.component.rawValue,
            operation: operation,
            origin: SentryTraceOriginAutoUiEventTracker
        )

        let idleTimeout = self.idleTimeout
        let configuration = SentryTracerConfiguration(block: { [idleTimeout] config in
            config.idleTimeout = idleTimeout
            config.waitForChildren = true
        })

        let transaction = SentrySDKInternal.currentHub().startTransaction(
            with: context,
            bindToScope: true,
            customSamplingContext: [:],
            configuration: configuration
        )

        SentrySDKLog.debug("Automatically started a new transaction with name: \(action)")
        return transaction
    }

    private func trackTransaction(_ transaction: SentryTracer) {
        transaction.finishCallback = { [weak self] tracer in
            guard let self else {
                return
            }

            self.activeTransactionsStorage.withLock { activeTransactions in
                activeTransactions.removeAll { $0 === tracer }
                SentrySDKLog.debug("Active transactions after removing tracer for span ID \(tracer.spanId.sentrySpanIdString): \(activeTransactions)")
            }
        }

        activeTransactionsStorage.withLock { activeTransactions in
            SentrySDKLog.debug("Adding transaction \(transaction.spanId.sentrySpanIdString) to list of active transactions (currently \(activeTransactions))")
            activeTransactions.append(transaction)
        }
    }
}

#endif // (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
