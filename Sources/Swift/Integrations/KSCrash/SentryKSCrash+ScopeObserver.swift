#if SDK_V10
internal import _SentryPrivate
internal import KSCrashRecording

extension SentryKSCrash.Scope {
    class Observer: NSObject, SentryScopeObserver {
        private func sync<K: Hashable, V>(
            dictionary: [K: V]?,
            syncToSentryCrash: (UnsafePointer<CChar>?) -> Void
        ) {
            sync(
                object: dictionary,
                serialize: { $0.isEmpty ? nil : $0 },
                syncToSentryCrash: syncToSentryCrash
            )
        }

        private func sync<T>(
            object: T?,
            serialize: (T) -> Any? = { $0 },
            syncToSentryCrash: (UnsafePointer<CChar>?) -> Void
        ) {
            guard
                let object,
                let serialized = serialize(object)
            else {
                syncToSentryCrash(nil)
                return
            }

            if let data = jsonEncodedCString(serialized) {
                syncToSentryCrash((data as NSData).bytes.assumingMemoryBound(to: CChar.self))
            }
        }

        private func jsonEncodedCString(_ serialized: Any) -> Data? {
            do {
                let data = try KSJSONCodec.encode(serialized, options: .sorted)

                return sentry_nullTerminated(data)
            } catch {
                SentrySDKLog.debug("Failed to encode object (\(serialized)) as JSON C-String with error: \(error)")
                return nil
            }
        }

        init(maxBreadcrumbs: UInt) {
            super.init()

            sentrycrash_scopesync_configureBreadcrumbs(Int(maxBreadcrumbs))
        }

        func setUser(_ user: User?) {
            sync(object: user) {
                $0.serialize()
            } syncToSentryCrash: {
                sentrycrash_scopesync_setUser($0)
            }
        }
        
        func setTags(_ tags: [String: String]?) {
            sync(dictionary: tags) {
                sentrycrash_scopesync_setTags($0)
            }
        }
        
        func setExtras(_ extras: [String: Any]?) {
            sync(dictionary: extras) {
                sentrycrash_scopesync_setExtras($0)
            }
        }
        
        func setContext(_ context: [String: [String: Any]]?) {
            sync(dictionary: context) {
                sentrycrash_scopesync_setContext($0)
            }
        }
        
        func setTraceContext(_ traceContext: [String: Any]?) {
            sync(dictionary: traceContext) {
                sentrycrash_scopesync_setTraceContext($0)
            }
        }
        
        func setDist(_ dist: String?) {
            sync(object: dist) {
                sentrycrash_scopesync_setDist($0)
            }
        }
        
        func setEnvironment(_ environment: String?) {
            sync(object: environment) {
                sentrycrash_scopesync_setEnvironment($0)
            }
        }

        func setFingerprint(_ fingerprint: [String]?) {
            sync(object: fingerprint) {
                $0.isEmpty ? nil : $0
            } syncToSentryCrash: {
                sentrycrash_scopesync_setFingerprint($0)
            }
        }
        
        func setLevel(_ level: SentryLevel) {
            sync(object: level) { level in
                if level == .none {
                    return nil
                }

                return level.description
            } syncToSentryCrash: {
                sentrycrash_scopesync_setLevel($0)
            }
        }
        
        func setAttributes(_ attributes: [String: Any]?) {
            // NOP - crash events don't support attributes
        }
        
        func addSerializedBreadcrumb(_ serializedBreadcrumb: [String: Any]) {
            sync(object: serializedBreadcrumb) {
                sentrycrash_scopesync_addBreadcrumb($0)
            }
        }
        
        func clearBreadcrumbs() {
            sentrycrash_scopesync_clearBreadcrumbs()
        }
        
        func clear() {
            sentrycrash_scopesync_clear()
        }
        
    }
}
#endif
