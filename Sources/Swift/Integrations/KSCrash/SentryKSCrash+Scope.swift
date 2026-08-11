#if ENABLE_KSCRASH
internal import _SentryPrivate

extension SentryKSCrash {
    enum Scope {}
}

extension SentryKSCrash.Scope {
    class Configuration {
        private let options: Options
        private let installer: SentryKSCrash.Installer

        private let observer: SentryKSCrash.Scope.Observer

        init(installer: SentryKSCrash.Installer, options: Options) {
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

                outerScope.add(observer)
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
