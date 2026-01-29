import Foundation
@_spi(Private) @testable import Sentry

/// Mock implementation of `SentryDispatchSemaphore` for unit testing.
///
/// This mock allows deterministic control over semaphore behavior in tests,
/// avoiding real time-based waits that can cause flakiness.
@_spi(Private) public final class TestSentryDispatchSemaphore: SentryDispatchSemaphore {
    
    private let lock = NSLock()
    private var _value: Int
    private var _shouldTimeout: Bool = false
    private var _timeoutDelay: TimeInterval = 0
    
    /// Whether the next `wait()` call should timeout.
    /// Setting this to `true` allows tests to simulate timeout behavior deterministically.
    public var shouldTimeout: Bool {
        get {
            lock.synchronized { _shouldTimeout }
        }
        set {
            lock.synchronized { _shouldTimeout = newValue }
        }
    }
    
    /// Delay before timeout occurs (for simulating timeout timing).
    /// Only used when `shouldTimeout` is `true`.
    public var timeoutDelay: TimeInterval {
        get {
            lock.synchronized { _timeoutDelay }
        }
        set {
            lock.synchronized { _timeoutDelay = newValue }
        }
    }
    
    /// Current semaphore value.
    public var value: Int {
        lock.synchronized { _value }
    }
    
    /// Invocations of `wait()` calls for testing.
    public var waitInvocations = Invocations<(timeout: DispatchTime, result: DispatchTimeoutResult)>()
    
    /// Invocations of `signal()` calls for testing.
    public var signalInvocations = Invocations<Int>()
    
    public required init(value: Int) {
        self._value = value
    }
    
    public func signal() -> Int {
        let previousValue = lock.synchronized {
            let prev = _value
            _value += 1
            signalInvocations.record(prev)
            return prev
        }
        return previousValue
    }
    
    public func wait(timeout: DispatchTime) -> DispatchTimeoutResult {
        let shouldTimeout = lock.synchronized { _shouldTimeout }
        let timeoutDelay = lock.synchronized { _timeoutDelay }
        
        if shouldTimeout {
            // Simulate timeout - wait for the specified delay then return timeout
            if timeoutDelay > 0 {
                Thread.sleep(forTimeInterval: timeoutDelay)
            }
            let result: DispatchTimeoutResult = .timedOut
            lock.synchronized {
                waitInvocations.record((timeout: timeout, result: result))
            }
            return result
        }
        
        // Simulate immediate success (semaphore was already signaled or will be)
        // In real tests, signal() should be called before wait() to simulate normal flow
        let result: DispatchTimeoutResult = .success
        lock.synchronized {
            waitInvocations.record((timeout: timeout, result: result))
        }
        return result
    }
    
    /// Resets the mock to its initial state.
    public func reset() {
        lock.synchronized {
            _value = 0
            _shouldTimeout = false
            _timeoutDelay = 0
            waitInvocations.removeAll()
            signalInvocations.removeAll()
        }
    }
}
