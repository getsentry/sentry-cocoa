import Foundation
import Sentry

public class MainThreadTestIntegration: NSObject, SentryIntegrationProtocol {

    public var installedInTheMainThread = false

    public func install(with options: Options) -> Bool {
        installedInTheMainThread = Thread.isMainThread
        return true
    }
}
