import Sentry

enum CrashE2EScopePopulation {
    static func populateIfNeeded() {
        guard CrashE2ERuntime.configuration.scenario == .crashTimeScope else { return }

        SentrySDK.configureScope { scope in
            let user = User(userId: "crash-e2e-scope-user")
            user.email = "crash-e2e-scope@example.com"
            user.username = "crash-e2e-scope"
            scope.setUser(user)
            scope.setTag(value: "crash-e2e-tag-value", key: "crash_e2e_tag")
            scope.setExtra(value: "crash-e2e-extra-value", key: "crash_e2e_extra")
            scope.setContext(value: ["marker": "crash-e2e-context"], key: "crash_e2e")
            scope.setDist("crash-e2e-dist")
            scope.setEnvironment("crash-e2e-environment")

            let breadcrumb = Breadcrumb(level: .info, category: "crash-e2e")
            breadcrumb.type = "debug"
            breadcrumb.message = "crash-e2e-breadcrumb"
            scope.addBreadcrumb(breadcrumb)
        }
    }
}
