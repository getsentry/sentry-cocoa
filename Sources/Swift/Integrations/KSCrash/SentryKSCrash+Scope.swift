#if SDK_V10
internal import _SentryPrivate

extension SentryKSCrash {
    enum Scope {}
}

extension SentryKSCrash.Scope {
    class Configuration {
        private let options: Options
        private let installer: SentryKSCrash.Installing

        private let observer: SentryKSCrash.Scope.Observer

        init(installer: SentryKSCrash.Installing, options: Options) {
            self.installer = installer
            self.options = options
            self.observer = .init(maxBreadcrumbs: options.maxBreadcrumbs)

            configure()
        }

        private func configure() {
            configureScope()
            configurePowerStateNotifications()
        }

        private func configureScope() {
            SentrySDKInternal.currentHub().configureScope { [weak self] outerScope in
                guard let self else { return }

                var userInfo = outerScope.serialize()

                // SentryCrashReportConverter.convertReportToEvent needs the release name, dist, and
                // environment of the SentryOptions in the UserInfo. When SentryCrash records a crash it
                // writes the UserInfo into SentryCrashField_User of the report.
                // SentryCrashReportConverter.initWithReport loads the contents of SentryCrashField_User
                // into self.userContext and convertReportToEvent can map the release name, dist, and
                // environment to the SentryEvent. Fixes GH-581 and GH-5260.
                userInfo["release"] = options.releaseName
                userInfo["dist"] = options.dist
                if userInfo["environment"] == nil {
                    userInfo["environment"] = options.environment
                }

                // Crashes don't use the attributes field, we remove them to avoid uploading them
                // unnecessarily.
                userInfo.removeValue(forKey: "attributes")
                installer.setUserInfo(userInfo)

                // add(_:) only observes later mutations. Seed current nested fields into
                // SentryScopeSyncC because KSCrash userInfo only stores scalars.
                outerScope.add(observer)
                seedObserver(from: outerScope)
            }
        }

        private func seedObserver(from scope: Scope) {
            observer.setUser(scope.userObject)
            observer.setTags(scope.tags)
            observer.setExtras(scope.extraDictionary as? [String: Any])
            observer.setContext(scope.contextDictionary as? [String: [String: Any]])
            observer.setEnvironment(scope.environmentString)
            observer.setDist(scope.distString)
            observer.setFingerprint(scope.fingerprintArray as? [String])
            observer.setLevel(scope.levelEnum)
            if let traceContext = scope.serialize()["traceContext"] as? [String: Any] {
                observer.setTraceContext(traceContext)
            }
            for breadcrumb in scope.breadcrumbs() {
                observer.addSerializedBreadcrumb(breadcrumb.serialize())
            }
        }

        private func configurePowerStateNotifications() {
            updateLowPowerModeScopeContext(ProcessInfo.processInfo)

            NotificationCenter.default.addObserver(
                self,
                selector: #selector(powerStateDidChange(_:)),
                name: NSNotification.Name.NSProcessInfoPowerStateDidChange,
                object: nil
            )
        }

        @objc private func powerStateDidChange(_ notification: Notification) {
            updateLowPowerModeScopeContext((notification.object as? ProcessInfo) ?? .processInfo)
        }

        private func updateLowPowerModeScopeContext(_ processInfo: ProcessInfo) {
            let isLowPowerModeEnabled = processInfo.isLowPowerModeEnabled

            SentrySDKInternal.currentHub().configureScope { scope in
                let existing = scope.contextDictionary[SENTRY_CONTEXT_DEVICE_KEY] as? [String: Any]
                var device = existing ?? [:]

                device["low_power_mode"] = isLowPowerModeEnabled
                scope.setContext(value: device, key: SENTRY_CONTEXT_DEVICE_KEY)
            }
        }
    }
}
#endif
