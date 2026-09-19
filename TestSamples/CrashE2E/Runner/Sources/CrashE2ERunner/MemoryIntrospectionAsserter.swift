import Foundation

/// Verifies that `options.enableMemoryIntrospection` controls crash-time memory introspection.
///
/// The app crashes while a pointer to a marker C string sits in a CPU register and in a stack slot
/// next to the stack pointer. The marker never reaches logs, exception reasons, or scope, so only
/// memory introspection can copy it into the report's `notable_addresses`, from which the report
/// converter promotes it into the exception value.
enum MemoryIntrospectionAsserter {
    /// Keep in sync with `g_memoryIntrospectionMarker` in `CrashE2EObjCBridge.mm`.
    static let marker = "crash-e2e-memory-introspection-marker"

    /// Checks the stored crash report before the drain launch converts and deletes it.
    static func assertStoredReportIfNeeded(scenario: Scenario, cacheRoot: URL, platform: String) throws {
        guard let expectsMarker = expectsMarker(for: scenario) else { return }

        let reports = try StoredCrashReports.urls(in: cacheRoot)
        guard reports.count == 1 else {
            try fail(
                "Expected exactly one stored crash report for \(platform)/\(scenario.rawValue) under "
                    + "\(cacheRoot.path), found \(reports.count)"
            )
        }

        let data = try Data(contentsOf: reports[0])
        guard let report = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            try fail("Malformed stored crash report for \(platform)/\(scenario.rawValue) at \(reports[0].path)")
        }

        let notableStrings = crashedThreadNotableStrings(in: report)
        if expectsMarker {
            try EventAssertions.assert(
                notableStrings.contains(marker),
                "Expected introspected marker in crashed thread notable_addresses for "
                    + "\(platform)/\(scenario.rawValue), found \(notableStrings)"
            )
        } else {
            try EventAssertions.assert(
                !containsMarker(data),
                "Expected no introspected marker in the stored crash report for "
                    + "\(platform)/\(scenario.rawValue) at \(reports[0].path)"
            )
        }
        log("✅ \(platform)/\(scenario.rawValue) stored crash report assertions passed.")
    }

    static func assertEventIfNeeded(scenario: Scenario, event: [String: Any],
                                    firstException: [String: Any], platform: String) throws {
        guard let expectsMarker = expectsMarker(for: scenario) else { return }

        if expectsMarker {
            let value = EventAssertions.string(firstException["value"]) ?? ""
            try EventAssertions.assert(
                value.contains(marker),
                "Expected introspected marker in exception value for \(platform)/\(scenario.rawValue), got: \(value)"
            )
        } else {
            let data = try JSONSerialization.data(withJSONObject: event)
            try EventAssertions.assert(
                !containsMarker(data),
                "Expected no introspected marker anywhere in the event for \(platform)/\(scenario.rawValue)"
            )
        }
    }

    /// Returns nil for scenarios unrelated to memory introspection.
    private static func expectsMarker(for scenario: Scenario) -> Bool? {
        if scenario == .memoryIntrospectionEnabled {
            return true
        }
        if scenario == .memoryIntrospectionDisabled || scenario == .memoryIntrospectionDefault {
            return false
        }
        return nil
    }

    private static func crashedThreadNotableStrings(in report: [String: Any]) -> [String] {
        let crash = EventAssertions.dictionary(report["crash"])
        let threads = crash["threads"] as? [[String: Any]] ?? []
        return threads
            .filter { ($0["crashed"] as? Bool) == true }
            .flatMap { thread -> [String] in
                EventAssertions.dictionary(thread["notable_addresses"]).values.compactMap { content in
                    let content = EventAssertions.dictionary(content)
                    guard EventAssertions.string(content["type"]) == "string" else { return nil }
                    return EventAssertions.string(content["value"])
                }
            }
    }

    private static func containsMarker(_ data: Data) -> Bool {
        data.range(of: Data(marker.utf8)) != nil
    }
}
