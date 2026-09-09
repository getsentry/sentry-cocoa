import Foundation

enum CrashTimeScopeAssertions {
    static func assert(_ event: [String: Any], platform: String, scenario: Scenario) throws {
        let user = EventAssertions.dictionary(event["user"])
        try EventAssertions.assert(
            EventAssertions.string(user["id"]) == "crash-e2e-scope-user",
            "Expected crash-time user id for \(platform)/\(scenario.rawValue)"
        )
        try EventAssertions.assert(
            EventAssertions.string(user["email"]) == "crash-e2e-scope@example.com",
            "Expected crash-time user email for \(platform)/\(scenario.rawValue)"
        )
        try EventAssertions.assert(
            EventAssertions.string(user["username"]) == "crash-e2e-scope",
            "Expected crash-time username for \(platform)/\(scenario.rawValue)"
        )

        try EventAssertions.assert(
            EventAssertions.string(event["dist"]) == "crash-e2e-dist",
            "Expected crash-time dist for \(platform)/\(scenario.rawValue)"
        )
        try EventAssertions.assert(
            EventAssertions.string(event["environment"]) == "crash-e2e-environment",
            "Expected crash-time environment for \(platform)/\(scenario.rawValue)"
        )

        let tags = EventAssertions.dictionary(event["tags"])
        try EventAssertions.assert(
            EventAssertions.string(tags["crash_e2e_tag"]) == "crash-e2e-tag-value",
            "Expected crash-time tag for \(platform)/\(scenario.rawValue)"
        )

        let extra = EventAssertions.dictionary(event["extra"])
        try EventAssertions.assert(
            EventAssertions.string(extra["crash_e2e_extra"]) == "crash-e2e-extra-value",
            "Expected crash-time extra for \(platform)/\(scenario.rawValue)"
        )

        let context = EventAssertions.dictionary(
            EventAssertions.dictionary(event["contexts"])["crash_e2e"]
        )
        try EventAssertions.assert(
            EventAssertions.string(context["marker"]) == "crash-e2e-context",
            "Expected crash-time context for \(platform)/\(scenario.rawValue)"
        )

        let breadcrumbs = event["breadcrumbs"] as? [[String: Any]] ?? []
        try EventAssertions.assert(
            breadcrumbs.contains {
                EventAssertions.string($0["category"]) == "crash-e2e"
                    && EventAssertions.string($0["message"]) == "crash-e2e-breadcrumb"
                    && EventAssertions.string($0["type"]) == "debug"
            },
            "Expected crash-time breadcrumb for \(platform)/\(scenario.rawValue)"
        )
    }
}
