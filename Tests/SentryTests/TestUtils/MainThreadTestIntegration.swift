import Foundation
import Sentry

public class MainThreadTestIntegration: NSObject, SentryIntegrationProtocol {
    
    private static var dispatchGroup: DispatchGroup?

    public var installedInTheMainThread = false

    public func install(with options: Options) -> Bool {
        installedInTheMainThread = Thread.isMainThread
        MainThreadTestIntegration.dispatchGroup?.leave()
        return true
    }
    
    public static func enterDispatchGroup() {
        dispatchGroup = DispatchGroup()
        dispatchGroup?.enter()
    }
    
    public static func waitForInstall() -> DispatchTimeoutResult {
        let result = MainThreadTestIntegration.dispatchGroup?.wait(timeout: .now() + 1.0) ?? DispatchTimeoutResult.timedOut
        dispatchGroup = nil
        return result
    }
}
