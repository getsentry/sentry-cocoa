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
                onCancellation()
                return nil
            }
            return Operation(identifier: identifier, session: self)
        }

        func cancel() {
            let cancellationCallbacks = state.withLock { state -> [() -> Void] in
                guard !state.isCancelled else {
                    return []
                }
                state.isCancelled = true

                var callbacks: [() -> Void] = []
                var cancelledOperationIDs: [UUID] = []
                for (identifier, operation) in state.operations {
                    switch operation {
                    case .pending(let onCancellation), .processing(let onCancellation):
                        callbacks.append(onCancellation)
                        cancelledOperationIDs.append(identifier)
                    case .captureCommitted:
                        break
                    }
                }
                for identifier in cancelledOperationIDs {
                    state.operations.removeValue(forKey: identifier)
                }
                return callbacks
            }

            for callback in cancellationCallbacks {
                callback()
            }
        }

        private func beginProcessing(identifier: UUID) -> Bool {
            state.withLock { state in
                guard case .pending(let onCancellation) = state.operations[identifier] else {
                    return false
                }
                state.operations[identifier] = .processing(onCancellation: onCancellation)
                return true
            }
        }

        private func commitCapture(identifier: UUID) -> Bool {
            let cancellationCallback = state.withLock { state -> (() -> Void)? in
                guard case .processing(let onCancellation) = state.operations[identifier] else {
                    return nil
                }
                state.operations[identifier] = .captureCommitted
                return onCancellation
            }
            return cancellationCallback != nil
        }

        private func complete(identifier: UUID, completion: () -> Void) {
            let completedOperation = state.withLock { state in
                state.operations.removeValue(forKey: identifier)
            }
            if completedOperation != nil {
                completion()
            }
        }
    }
}
#endif
