#if ENABLE_KSCRASH
import Foundation

extension SentryKSCrash {
    /// Owns the report-processing operations started by one integration installation.
    final class ReportProcessingSession {
        final class Operation {
            private let identifier: UUID
            private let session: ReportProcessingSession

            fileprivate init(identifier: UUID, session: ReportProcessingSession) {
                self.identifier = identifier
                self.session = session
            }

            func beginProcessing() -> Bool {
                session.beginProcessing(identifier: identifier)
            }

            func commitCapture() -> Bool {
                session.commitCapture(identifier: identifier)
            }

            func complete(_ completion: () -> Void) {
                session.complete(identifier: identifier, completion: completion)
            }
        }

        private enum OperationState {
            case pending(onCancellation: () -> Void)
            case processing(onCancellation: () -> Void)
            case captureCommitted
        }

        private struct State {
            var isCancelled = false
            var operations: [UUID: OperationState] = [:]
        }

        static let cancellationError = NSError(
            domain: "io.sentry.kscrash-report-processing",
            code: 1,
            userInfo: [
                NSLocalizedDescriptionKey:
                    "KSCrash report processing was cancelled because the SDK integration was uninstalled."
            ]
        )

        private let state = SentryMutex(State())

        var isCancelled: Bool {
            state.withLock { $0.isCancelled }
        }

        func register(onCancellation: @escaping () -> Void) -> Operation? {
            let identifier = UUID()
            let didRegister = state.withLock { state in
                guard !state.isCancelled else {
                    return false
                }
                state.operations[identifier] = .pending(onCancellation: onCancellation)
                return true
            }

            guard didRegister else {
                SentrySDKLog.debug(
                    "Rejecting KSCrash report processing operation \(identifier) because the session is cancelled."
                )
                onCancellation()
                return nil
            }
            SentrySDKLog.debug("Registered KSCrash report processing operation \(identifier).")
            return Operation(identifier: identifier, session: self)
        }

        func cancel() {
            let cancellation = state.withLock { state -> (
                didCancel: Bool,
                operations: [(identifier: UUID, callback: () -> Void)],
                committedOperationCount: Int
            ) in
                guard !state.isCancelled else {
                    return (false, [], 0)
                }
                state.isCancelled = true

                var operations: [(identifier: UUID, callback: () -> Void)] = []
                var committedOperationCount = 0
                for (identifier, operation) in state.operations {
                    switch operation {
                    case .pending(let onCancellation), .processing(let onCancellation):
                        operations.append((identifier, onCancellation))
                    case .captureCommitted:
                        committedOperationCount += 1
                    }
                }
                for operation in operations {
                    state.operations.removeValue(forKey: operation.identifier)
                }
                return (true, operations, committedOperationCount)
            }

            guard cancellation.didCancel else {
                SentrySDKLog.debug("Ignoring repeated KSCrash report processing session cancellation.")
                return
            }
            SentrySDKLog.debug(
                "Cancelling KSCrash report processing session with \(cancellation.operations.count) active operation(s); allowing \(cancellation.committedOperationCount) committed capture(s) to complete."
            )
            for operation in cancellation.operations {
                SentrySDKLog.debug(
                    "Cancelling KSCrash report processing operation \(operation.identifier)."
                )
                operation.callback()
            }
        }

        private func beginProcessing(identifier: UUID) -> Bool {
            let didBegin = state.withLock { state in
                guard case .pending(let onCancellation) = state.operations[identifier] else {
                    return false
                }
                state.operations[identifier] = .processing(onCancellation: onCancellation)
                return true
            }
            if didBegin {
                SentrySDKLog.debug("Began KSCrash report processing operation \(identifier).")
            } else {
                SentrySDKLog.debug(
                    "Skipping KSCrash report processing operation \(identifier) because it is no longer pending."
                )
            }
            return didBegin
        }

        private func commitCapture(identifier: UUID) -> Bool {
            let didCommit = state.withLock { state in
                guard case .processing = state.operations[identifier] else {
                    return false
                }
                state.operations[identifier] = .captureCommitted
                return true
            }
            if didCommit {
                SentrySDKLog.debug(
                    "Committed capture for KSCrash report processing operation \(identifier)."
                )
            } else {
                SentrySDKLog.debug(
                    "Skipping capture commit for KSCrash report processing operation \(identifier) because it is no longer processing."
                )
            }
            return didCommit
        }

        private func complete(identifier: UUID, completion: () -> Void) {
            let completedOperation = state.withLock { state in
                state.operations.removeValue(forKey: identifier)
            }
            guard let completedOperation else {
                SentrySDKLog.debug(
                    "Ignoring completion for KSCrash report processing operation \(identifier) because it is no longer active."
                )
                return
            }

            let operationState: String
            switch completedOperation {
            case .pending:
                operationState = "pending"
            case .processing:
                operationState = "processing"
            case .captureCommitted:
                operationState = "capture-committed"
            }
            SentrySDKLog.debug(
                "Completing KSCrash report processing operation \(identifier) from the \(operationState) state."
            )
            completion()
        }
    }
}
#endif
