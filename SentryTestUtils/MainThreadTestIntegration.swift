import Foundation
import Sentry

public class MainThreadTestIntegration : NSObject, SentryIntegrationProtocol {

    public var installedInTheMainThread = false

    public func install(with options: Options) -> Bool {
        installedInTheMainThread = Thread.isMainThread
        return true
    }

    public static func replaceOptionIntegrations(_ options: Options) {
        options.integrations = [ NSStringFromClass(MainThreadTestIntegration.self) ]
    }
}
