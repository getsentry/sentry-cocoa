@testable import Sentry

@objc public class SentryProfilerAsyncAwaitTestFixture: NSObject {
    @objc public class func startAsyncTransaction() -> (any Span)? {
        if #available(iOS 13.0, watchOS 6.0, tvOS 13.0, macOS 10.15, *) {
            let transaction = SentrySDK.startTransaction(name: "async_transaction", operation: "async_op")
            Task.detached(priority: .background) {
                func fib(n: Int) async -> Int {
                    if n == 0 { return 0 }
                    if n == 1 { return 1 }
                    return await fib(n: n - 1) + fib(n: n - 2)
                }
                print(await fib(n: 100))
            }
            return transaction
        }
        return nil
    }
}
