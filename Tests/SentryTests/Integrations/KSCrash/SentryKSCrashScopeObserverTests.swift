@_spi(Private) @testable import Sentry
import XCTest

final class SentryKSCrashScopeObserverTests: XCTestCase {

    override func tearDown() {
        ScopeJSON.clear()
        super.tearDown()
    }

    func test_userChanged_writesScopeJSON() throws {
        let sut = SentryKSCrashScopeObserver(maxBreadcrumbs: 10)
        let user = User(userId: "abc")
        user.email = "test@test.com"
        sut.setUser(user)

        let json = try storedScopeDict()
        let storedUser = json?["user"] as? [String: Any]
        XCTAssertEqual(storedUser?["id"] as? String, "abc")
        XCTAssertEqual(storedUser?["email"] as? String, "test@test.com")
    }

    func test_userCleared_removesUserFromJSON() throws {
        let sut = SentryKSCrashScopeObserver(maxBreadcrumbs: 10)
        let user = User(userId: "abc")
        sut.setUser(user)
        sut.setUser(nil)

        let json = try storedScopeDict()
        XCTAssertNil(json?["user"])
    }

    func test_addBreadcrumb_appearsInStoredJSON() throws {
        let sut = SentryKSCrashScopeObserver(maxBreadcrumbs: 5)
        sut.addSerializedBreadcrumb(["message": "hello", "category": "test", "level": "info"])

        let crumbs = try storedScopeDict()?["breadcrumbs"] as? [[String: Any]]
        XCTAssertEqual(crumbs?.count, 1)
        XCTAssertEqual(crumbs?.first?["message"] as? String, "hello")
    }

    func test_breadcrumbs_ringBuffer_evictsOldest() throws {
        let sut = SentryKSCrashScopeObserver(maxBreadcrumbs: 3)
        for i in 0..<5 {
            sut.addSerializedBreadcrumb(["message": "msg\(i)", "category": "test"])
        }

        let crumbs = try storedScopeDict()?["breadcrumbs"] as? [[String: Any]]
        XCTAssertEqual(crumbs?.count, 3)
        XCTAssertEqual(crumbs?[0]["message"] as? String, "msg2")
        XCTAssertEqual(crumbs?[1]["message"] as? String, "msg3")
        XCTAssertEqual(crumbs?[2]["message"] as? String, "msg4")
    }

    func test_clearBreadcrumbs_removesAllCrumbs() throws {
        let sut = SentryKSCrashScopeObserver(maxBreadcrumbs: 5)
        sut.addSerializedBreadcrumb(["message": "hello", "category": "x"])
        sut.clearBreadcrumbs()

        let crumbs = try storedScopeDict()?["breadcrumbs"] as? [[String: Any]]
        XCTAssertNil(crumbs)
    }

    func test_tagsChanged_writesTagsToJSON() throws {
        let sut = SentryKSCrashScopeObserver(maxBreadcrumbs: 1)
        sut.setTags(["env": "prod", "version": "1.0"])

        let tags = try storedScopeDict()?["tags"] as? [String: String]
        XCTAssertEqual(tags?["env"], "prod")
        XCTAssertEqual(tags?["version"], "1.0")
    }

    func test_extrasChanged_writesExtrasToJSON() throws {
        let sut = SentryKSCrashScopeObserver(maxBreadcrumbs: 1)
        sut.setExtras(["key": "value"])

        let extras = try storedScopeDict()?["extra"] as? [String: String]
        XCTAssertEqual(extras?["key"], "value")
    }

    func test_distChanged_writesDistToJSON() throws {
        let sut = SentryKSCrashScopeObserver(maxBreadcrumbs: 1)
        sut.setDist("abc123")

        XCTAssertEqual(try storedScopeDict()?["dist"] as? String, "abc123")
    }

    func test_environmentChanged_writesEnvironmentToJSON() throws {
        let sut = SentryKSCrashScopeObserver(maxBreadcrumbs: 1)
        sut.setEnvironment("production")

        XCTAssertEqual(try storedScopeDict()?["environment"] as? String, "production")
    }

    func test_fingerprintChanged_writesFingerprintToJSON() throws {
        let sut = SentryKSCrashScopeObserver(maxBreadcrumbs: 1)
        sut.setFingerprint(["a", "b", "c"])

        let fingerprint = try storedScopeDict()?["fingerprint"] as? [String]
        XCTAssertEqual(fingerprint, ["a", "b", "c"])
    }

    func test_levelChanged_writesLevelToJSON() throws {
        let sut = SentryKSCrashScopeObserver(maxBreadcrumbs: 1)
        sut.setLevel(.error)

        XCTAssertEqual(try storedScopeDict()?["level"] as? String, "error")
    }

    func test_levelNone_doesNotWriteLevel() throws {
        let sut = SentryKSCrashScopeObserver(maxBreadcrumbs: 1)
        sut.setLevel(.error)
        sut.setLevel(.none)

        XCTAssertNil(try storedScopeDict()?["level"])
    }

    func test_clear_removesAllData() throws {
        let sut = SentryKSCrashScopeObserver(maxBreadcrumbs: 5)
        sut.setUser(User(userId: "abc"))
        sut.setTags(["env": "prod"])
        sut.addSerializedBreadcrumb(["message": "hello"])
        sut.clear()

        let json = try storedScopeDict()
        XCTAssertNil(json?["user"])
        XCTAssertNil(json?["tags"])
        XCTAssertNil(json?["breadcrumbs"])
    }

    func test_traceContext_writesToJSON() throws {
        let sut = SentryKSCrashScopeObserver(maxBreadcrumbs: 1)
        sut.setTraceContext(["trace_id": "abc123"])

        let tc = try storedScopeDict()?["trace_context"] as? [String: Any]
        XCTAssertEqual(tc?["trace_id"] as? String, "abc123")
    }

    func test_context_writesToJSON() throws {
        let sut = SentryKSCrashScopeObserver(maxBreadcrumbs: 1)
        sut.setContext(["device": ["model": "iPhone"]])

        let context = try storedScopeDict()?["context"] as? [String: [String: Any]]
        XCTAssertEqual(context?["device"]?["model"] as? String, "iPhone")
    }

    func test_emptyTags_omittedFromJSON() throws {
        let sut = SentryKSCrashScopeObserver(maxBreadcrumbs: 1)
        sut.setTags(["env": "prod"])
        sut.setTags([:])
        XCTAssertNil(try storedScopeDict()?["tags"])
    }

    func test_emptyExtras_omittedFromJSON() throws {
        let sut = SentryKSCrashScopeObserver(maxBreadcrumbs: 1)
        sut.setExtras(["key": "val"])
        sut.setExtras([:])
        XCTAssertNil(try storedScopeDict()?["extra"])
    }

    func test_emptyContext_omittedFromJSON() throws {
        let sut = SentryKSCrashScopeObserver(maxBreadcrumbs: 1)
        sut.setContext(["device": ["model": "iPhone"]])
        sut.setContext([:])
        XCTAssertNil(try storedScopeDict()?["context"])
    }

    func test_emptyTraceContext_omittedFromJSON() throws {
        let sut = SentryKSCrashScopeObserver(maxBreadcrumbs: 1)
        sut.setTraceContext(["trace_id": "abc"])
        sut.setTraceContext([:])
        XCTAssertNil(try storedScopeDict()?["trace_context"])
    }

    func test_emptyFingerprint_omittedFromJSON() throws {
        let sut = SentryKSCrashScopeObserver(maxBreadcrumbs: 1)
        sut.setFingerprint(["a", "b"])
        sut.setFingerprint([])
        XCTAssertNil(try storedScopeDict()?["fingerprint"])
    }

    func test_nilDist_omittedFromJSON() throws {
        let sut = SentryKSCrashScopeObserver(maxBreadcrumbs: 1)
        sut.setDist("v1")
        sut.setDist(nil)
        XCTAssertNil(try storedScopeDict()?["dist"])
    }

    func test_nilEnvironment_omittedFromJSON() throws {
        let sut = SentryKSCrashScopeObserver(maxBreadcrumbs: 1)
        sut.setEnvironment("prod")
        sut.setEnvironment(nil)
        XCTAssertNil(try storedScopeDict()?["environment"])
    }

    func test_unrelatedFieldUpdate_preservesOtherFields() throws {
        let sut = SentryKSCrashScopeObserver(maxBreadcrumbs: 1)
        sut.setUser(User(userId: "u1"))
        sut.setDist("v2")

        let json = try storedScopeDict()
        XCTAssertEqual(json?["dist"] as? String, "v2")
        XCTAssertEqual((json?["user"] as? [String: Any])?["id"] as? String, "u1")
    }

    // MARK: - Helper

    private func storedScopeDict() throws -> [String: Any]? {
        guard let data = ScopeJSON.get()?.data(using: .utf8) else { return nil }

        return try JSONSerialization.jsonObject(with: data) as? [String: Any]
    }
}
