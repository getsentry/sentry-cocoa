import Foundation

enum ScenarioEventAsserter {
    static func assertScenarioEvent(_ scenario: Scenario, cacheRoot: URL,
                                    platform: String, artifactsDir: URL) throws {
        let events = try EnvelopeReader.exceptionEvents(in: cacheRoot)
        if !scenario.expectsEvent {
            guard events.isEmpty else {
                try fail("Expected no event envelope for \(platform)/\(scenario.rawValue) under \(cacheRoot.path), found \(events.count)")
            }
            log("✅ \(platform)/\(scenario.rawValue) no-event assertion passed.")
            return
        }

        guard events.count == 1 else {
            try fail("Expected exactly one event envelope for \(platform)/\(scenario.rawValue) under \(cacheRoot.path), found \(events.count)")
        }

        let eventPath = artifactsDir.appendingPathComponent("\(platform)-\(scenario.rawValue)-event.json")
        let event = events[0].event
        try EnvelopeReader.writeEvent(event, to: eventPath)
        log("Extracted event: \(eventPath.path)")

        do {
            try EventAssertions.assertScenario(scenario, platform: platform, event: event, cacheRoot: cacheRoot)
        } catch {
            log("Event JSON:")
            print(prettyJSON(event))
            throw error
        }

        log("✅ \(platform)/\(scenario.rawValue) assertions passed.")
    }
}
