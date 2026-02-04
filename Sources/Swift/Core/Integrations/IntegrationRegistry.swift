// swiftlint:disable missing_docs
@_implementationOnly import _SentryPrivate
import Foundation

/// Thread-safe registry for managing installed integrations.
/// This class is the single source of truth for integration storage,
/// allowing SentryIntegrationProtocol to be a pure Swift protocol.
@_spi(Private) @objc public final class IntegrationRegistry: NSObject {
    private let lock = NSLock()
    private var integrations: [any SwiftIntegration] = []
    private var integrationNames: Set<String> = []
    
    @objc public func add(_ integration: Any, name: String) {
        guard let swiftIntegration = integration as? (any SwiftIntegration) else {
            SentrySDKLog.error("Attempted to add non-SentryIntegrationProtocol integration: \(type(of: integration))")
            return
        }
        lock.synchronized {
            integrations.append(swiftIntegration)
            integrationNames.insert(name)
        }
        SentrySDKLog.debug("Integration installed: \(name)")
    }
    
    /// Gets an integration by its class. This method is kept for backwards compatibility
    /// but Swift callers should use the generic `getIntegration<T>(_ type: T.Type)` instead.
    func getIntegration(_ integrationClass: AnyClass) -> (any SwiftIntegration)? {
        lock.synchronized {
            for integration in integrations {
                if type(of: integration) == integrationClass {
                    return integration
                }
            }
            return nil
        }
    }
    
    /// Gets an integration by its Swift type. Use this from Swift code.
    func getIntegration<T: SwiftIntegration>(_ type: T.Type) -> T? {
        lock.synchronized {
            for integration in integrations {
                if let match = integration as? T {
                    return match
                }
            }
            return nil
        }
    }
    
    @objc public func isInstalled(_ integrationClass: AnyClass) -> Bool {
        lock.synchronized {
            for integration in integrations {
                if type(of: integration) == integrationClass {
                    return true
                }
            }
            return false
        }
    }
    
    @objc public func hasIntegration(_ name: String) -> Bool {
        lock.synchronized {
            integrationNames.contains(name)
        }
    }
    
    @objc public func removeAll() {
        let integrationsToUninstall = lock.synchronized {
            let snapshot = integrations
            integrations.removeAll()
            integrationNames.removeAll()
            return snapshot
        }
        
        for integration in integrationsToUninstall {
            integration.uninstall()
        }
    }
    
    /// Returns all installed integrations.
    var allIntegrations: [any SwiftIntegration] {
        lock.synchronized {
            integrations
        }
    }
    
    @objc public var allIntegrationNames: Set<String> {
        lock.synchronized {
            integrationNames
        }
    }
    
    /// Flushes all flushable integrations with the given timeout.
    /// - Parameter timeout: Maximum time to spend flushing.
    /// - Returns: The actual time spent flushing.
    @objc public func flushIntegrations(timeout: TimeInterval) -> TimeInterval {
        let dateProvider = SentryDependencyContainer.sharedInstance().dateProvider
        let startTimeNs = dateProvider.getAbsoluteTime()
        
        let integrationsSnapshot = lock.synchronized { integrations }
        
        for integration in integrationsSnapshot {
            let currentTimeNs = dateProvider.getAbsoluteTime()
            let elapsedTime = TimeInterval(currentTimeNs - startTimeNs) / 1_000_000_000
            if elapsedTime >= timeout {
                SentrySDKLog.debug("Flush integrations timeout exceeded (\(elapsedTime)s >= \(timeout)s). Stopping flush of remaining integrations.")
                break
            }
            
            if let flushable = integration as? any FlushableIntegration {
                flushable.flush()
            }
        }
        
        let endTimeNs = dateProvider.getAbsoluteTime()
        return TimeInterval(endTimeNs - startTimeNs) / 1_000_000_000
    }
}
// MARK: - SentryHubInternal Extension

/// Extension to expose the integration registry on SentryHubInternal.
/// This is necessary because the ObjC header declares `integrationRegistry` as an
/// `IntegrationRegistry*` property, but `IntegrationRegistry` is `@_spi(Private)`,
/// so Swift code can't see the property through the ObjC bridging without this extension.
extension SentryHubInternal {
    /// Provides typed access to the integration registry.
    /// This computed property accesses the underlying ObjC property and casts it to the proper type.
    var integrationRegistry: IntegrationRegistry {
        // swiftlint:disable:next force_cast
        value(forKey: "integrationRegistry") as! IntegrationRegistry
    }
}
// swiftlint:enable missing_docs
