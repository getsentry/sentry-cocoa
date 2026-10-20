/// A thread-safe operation that executes at most once over the lifetime of the instance.
///
/// Call the instance like a function to execute its operation with the first caller's input.
/// Use a tuple as `Input` for multiple arguments, or `Void` for a parameterless operation.
/// The first caller takes the operation and executes it synchronously on its calling thread.
/// Subsequent calls, including reentrant calls from the operation itself, have no effect.
///
/// The operation executes outside the lock. Concurrent callers do not wait for it to finish,
/// so returning from a call does not guarantee that the operation has completed.
final class SentryOnce<Input> {
    private let operation: SentryMutex<((Input) -> Void)?>

    /// Creates a once-only operation without executing it.
    ///
    /// - Parameter operation: The closure to execute with the first caller's input. Its stored
    ///   reference is cleared before execution to release captured values when execution finishes.
    init(_ operation: @escaping (Input) -> Void) {
        self.operation = SentryMutex(operation)
    }

    /// Executes the operation with the supplied input if no caller has taken it yet.
    ///
    /// This method is safe to call concurrently or reentrantly. The operation runs on the
    /// winning caller's thread and is responsible for any thread or actor requirements of its work.
    ///
    /// - Parameter input: The value passed to the operation if this call takes it.
    func callAsFunction(_ input: Input) {
        let operation = self.operation.withLock {
            let operation = $0
            $0 = nil
            return operation
        }
        operation?(input)
    }
}

extension SentryOnce where Input == Void {
    /// Creates a parameterless once-only operation without executing it.
    ///
    /// - Parameter operation: The closure to execute on the first call.
    convenience init(_ operation: @escaping () -> Void) {
        self.init { _ in operation() }
    }

    /// Executes the parameterless operation if no caller has taken it yet.
    func callAsFunction() {
        self(())
    }
}
