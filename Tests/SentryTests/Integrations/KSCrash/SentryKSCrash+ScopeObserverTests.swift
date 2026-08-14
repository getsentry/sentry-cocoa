#if SDK_V10
@_spi(Private) @testable import Sentry
import Foundation
import SentryTestUtils
import XCTest

class SentryKSCrashScopeObserverTests: XCTestCase {

    private struct Fixture {
        let dist = "dist"
        let environment = "environment"
        let tags = ["tag": "tag", "tag1": "tag1"]
        let extras = ["extra": [1, 2], "extra2": "tag1"] as [String: Any]
        let fingerprint = ["a", "b", "c"]
        let maxBreadcrumbs: UInt = 10

        var sut: SentryKSCrash.Scope.Observer {
            return .init(maxBreadcrumbs: maxBreadcrumbs)
        }
    }

    private let fixture = Fixture()

    func testSetUser_whenUserIsDefined_shouldSerializeUser() throws {
        // -- Arrange --
        let sut = fixture.sut
        let user = TestData.user

        // -- Act --
        sut.setUser(user)

        let expected = try serialize(object: user.serialize())

        // -- Assert --
        XCTAssertEqual(expected, getScopeJson { $0.user })
    }

    func testSetUser_whenUserIsNil_shouldClearUser() {
        // -- Arrange --
        let sut = fixture.sut
        sut.setUser(TestData.user)

        // -- Act --
        sut.setUser(nil)

        // -- Assert --
        XCTAssertNil(getScopeJson { $0.user })
    }

    func testSetLevel_whenLevelIsFatal_shouldSerializeLevel() {
        // -- Arrange --
        let sut = fixture.sut
        let level = SentryLevel.fatal

        // -- Act --
        sut.setLevel(level)

        // -- Assert --
        XCTAssertEqual("\"fatal\"", getScopeJson { $0.level })
    }

    func testSetLevel_whenLevelIsNone_shouldClearLevel() {
        // -- Arrange --
        let sut = fixture.sut
        sut.setLevel(SentryLevel.fatal)

        // -- Act --
        sut.setLevel(SentryLevel.none)

        // -- Assert --
        XCTAssertNil(getScopeJson { $0.level })
    }

    func testSetDist_whenDistIsDefined_shouldSerializeDist() throws {
        // -- Arrange --
        let sut = fixture.sut

        // -- Act --
        sut.setDist(fixture.dist)

        let expected = try serialize(object: fixture.dist)

        // -- Assert --
        XCTAssertEqual(expected, getScopeJson { $0.dist })
    }

    func testSetDist_whenDistIsNil_shouldClearDist() {
        // -- Arrange --
        let sut = fixture.sut
        sut.setDist(fixture.dist)

        // -- Act --
        sut.setDist(nil)

        // -- Assert --
        XCTAssertNil(getScopeJson { $0.dist })
    }

    func testSetEnvironment_whenEnvironmentIsDefined_shouldSerializeEnvironment() throws {
        // -- Arrange --
        let sut = fixture.sut

        // -- Act --
        sut.setEnvironment(fixture.environment)

        let expected = try serialize(object: fixture.environment)

        // -- Assert --
        XCTAssertEqual(expected, getScopeJson { $0.environment })
    }

    func testSetEnvironment_whenEnvironmentIsNil_shouldClearEnvironment() {
        // -- Arrange --
        let sut = fixture.sut
        sut.setEnvironment(fixture.environment)

        // -- Act --
        sut.setEnvironment(nil)

        // -- Assert --
        XCTAssertNil(getScopeJson { $0.environment })
    }

    func testSetContext_whenContextIsDefined_shouldSerializeContext() throws {
        // -- Arrange --
        let sut = fixture.sut

        // -- Act --
        sut.setContext(TestData.context)

        let expected = try serialize(object: TestData.context)

        // -- Assert --
        XCTAssertEqual(expected, getScopeJson { $0.context })
    }

    func testSetContext_whenContextIsNil_shouldClearContext() {
        // -- Arrange --
        let scope = Scope()
        let sut = fixture.sut
        scope.add(sut)
        TestData.setContext(scope)

        // -- Act --
        sut.setContext(nil)

        // -- Assert --
        XCTAssertNil(getScopeJson { $0.context })
    }

    func testSetContext_whenContextIsEmpty_shouldClearContext() {
        // -- Arrange --
        let scope = Scope()
        let sut = fixture.sut
        scope.add(sut)
        TestData.setContext(scope)

        // -- Act --
        sut.setContext([:])

        // -- Assert --
        XCTAssertNil(getScopeJson { $0.context })
    }

    func testSetTraceContext_whenTraceContextIsDefined_shouldSerializeTraceContext() throws {
        // -- Arrange --
        let sut = fixture.sut

        // -- Act --
        sut.setTraceContext(TestData.traceContext)

        let expected = try serialize(object: TestData.traceContext)

        // -- Assert --
        XCTAssertEqual(expected, getScopeJson { $0.traceContext })
    }

    func testSetTraceContext_whenTraceContextIsNil_shouldClearTraceContext() {
        // -- Arrange --
        let sut = fixture.sut
        sut.setTraceContext(TestData.traceContext)

        // -- Act --
        sut.setTraceContext(nil)

        // -- Assert --
        XCTAssertNil(getScopeJson { $0.traceContext })
    }

    func testSetTraceContext_whenTraceContextIsEmpty_shouldClearTraceContext() {
        // -- Arrange --
        let sut = fixture.sut
        sut.setTraceContext(TestData.traceContext)

        // -- Act --
        sut.setTraceContext([:])

        // -- Assert --
        XCTAssertNil(getScopeJson { $0.traceContext })
    }

    func testSetFingerprint_whenFingerprintIsDefined_shouldSerializeFingerprint() throws {
        // -- Arrange --
        let sut = fixture.sut

        // -- Act --
        sut.setFingerprint(fixture.fingerprint)

        let expected = try serialize(object: fixture.fingerprint)

        // -- Assert --
        XCTAssertEqual(expected, getScopeJson { $0.fingerprint })
    }

    func testSetFingerprint_whenFingerprintIsNil_shouldClearFingerprint() {
        // -- Arrange --
        let sut = fixture.sut
        sut.setFingerprint(fixture.fingerprint)

        // -- Act --
        sut.setFingerprint(nil)

        // -- Assert --
        XCTAssertNil(getScopeJson { $0.fingerprint })
    }

    func testSetFingerprint_whenFingerprintIsEmpty_shouldClearFingerprint() {
        // -- Arrange --
        let sut = fixture.sut
        sut.setFingerprint(fixture.fingerprint)

        // -- Act --
        sut.setFingerprint([])

        // -- Assert --
        XCTAssertNil(getScopeJson { $0.fingerprint })
    }

    func testSetExtras_whenExtrasAreDefined_shouldSerializeExtras() throws {
        // -- Arrange --
        let sut = fixture.sut

        // -- Act --
        sut.setExtras(fixture.extras)

        let expected = try serialize(object: fixture.extras)

        // -- Assert --
        XCTAssertEqual(expected, getScopeJson { $0.extras })
    }

    func testSetExtras_whenExtrasAreNil_shouldClearExtras() {
        // -- Arrange --
        let sut = fixture.sut
        sut.setExtras(fixture.extras)

        // -- Act --
        sut.setExtras(nil)

        // -- Assert --
        XCTAssertNil(getScopeJson { $0.extras })
    }

    func testSetExtras_whenExtrasAreEmpty_shouldClearExtras() {
        // -- Arrange --
        let sut = fixture.sut
        sut.setExtras(fixture.extras)

        // -- Act --
        sut.setExtras([:])

        // -- Assert --
        XCTAssertNil(getScopeJson { $0.extras })
    }

    func testSetTags_whenTagsAreDefined_shouldSerializeTags() throws {
        // -- Arrange --
        let sut = fixture.sut

        // -- Act --
        sut.setTags(fixture.tags)

        let expected = try serialize(object: fixture.tags)

        // -- Assert --
        XCTAssertEqual(expected, getScopeJson { $0.tags })
    }

    func testSetTags_whenTagsAreNil_shouldClearTags() {
        // -- Arrange --
        let sut = fixture.sut
        sut.setTags(fixture.tags)

        // -- Act --
        sut.setTags(nil)

        // -- Assert --
        XCTAssertNil(getScopeJson { $0.tags })
    }

    func testSetTags_whenTagsAreEmpty_shouldClearTags() {
        // -- Arrange --
        let sut = fixture.sut
        sut.setTags(fixture.tags)

        // -- Act --
        sut.setTags([:])

        // -- Assert --
        XCTAssertNil(getScopeJson { $0.tags })
    }

    func testAddSerializedBreadcrumb_whenBreadcrumbIsDefined_shouldSerializeBreadcrumb() throws {
        // -- Arrange --
        let sut = fixture.sut
        let crumb = TestData.crumb

        // -- Act --
        sut.addSerializedBreadcrumb(crumb.serialize())

        // -- Assert --
        try assertOneCrumbSetToScope(crumb: crumb)
    }

    func testAddBreadcrumb_whenScopeIsNotConfigured_shouldNotCrash() {
        // -- Act & Assert --
        sentrycrash_scopesync_addBreadcrumb("")
    }

    func testConfigureBreadcrumbs_whenCalledTwice_shouldResetBreadcrumbs() throws {
        // -- Arrange --
        let sut = fixture.sut
        let crumb = TestData.crumb
        sut.addSerializedBreadcrumb(crumb.serialize())

        // -- Act --
        sentrycrash_scopesync_configureBreadcrumbs(Int(fixture.maxBreadcrumbs))

        // -- Assert --
        let scope = sentrycrash_scopesync_getScope()
        XCTAssertEqual(0, scope.pointee.currentCrumb)

        sut.addSerializedBreadcrumb(crumb.serialize())
        try assertOneCrumbSetToScope(crumb: crumb)
    }

    func testAddSerializedBreadcrumb_whenExceedingMaximum_shouldOverwriteOldestBreadcrumb() throws {
        // -- Arrange --
        let sut = fixture.sut

        var crumbs: [Breadcrumb] = []

        // -- Act --
        for i in 0...fixture.maxBreadcrumbs {
            let crumb = TestData.crumb
            crumb.message = "\(i)"
            sut.addSerializedBreadcrumb(crumb.serialize())
            crumbs.append(crumb)
        }
        crumbs.removeFirst()

        // -- Assert --
        let scope = sentrycrash_scopesync_getScope()

        XCTAssertEqual(1, scope.pointee.currentCrumb)

        guard let breadcrumbs = scope.pointee.breadcrumbs else {
            XCTFail("Pointer to breadcrumbs is nil.")
            return
        }

        // Breadcrumbs are stored with a ring buffer. Therefore,
        // we need to start where the current crumb is
        var i = scope.pointee.currentCrumb
        var crumbPointer = breadcrumbs[i]
        for crumb in crumbs {
            let scopeCrumbJSON = String(cString: crumbPointer ?? UnsafeMutablePointer<CChar>.allocate(capacity: 0))

            XCTAssertEqual(try serialize(object: crumb.serialize()), scopeCrumbJSON)

            i = (i + 1) % Int(fixture.maxBreadcrumbs)
            crumbPointer = breadcrumbs[i]
        }
    }

    func testClear_whenScopeHasValues_shouldClearScope() {
        // -- Arrange --
        let sut = fixture.sut
        let user = TestData.user
        sut.setUser(user)
        sut.setDist(fixture.dist)
        sut.setContext(TestData.context)
        sut.setEnvironment(fixture.environment)
        sut.setTags(fixture.tags)
        sut.setExtras(fixture.extras)
        sut.setFingerprint(fixture.fingerprint)
        sut.setLevel(SentryLevel.fatal)
        sut.addSerializedBreadcrumb(TestData.crumb.serialize())

        // -- Act --
        sut.clear()

        // -- Assert --
        assertEmptyScope()
    }

    func testInit_whenScopeIsConfigured_shouldCreateEmptyScope() {

        // -- Act --
        let sut = fixture.sut

        // -- Assert --
        XCTAssertNotNil(sut)
        assertEmptyScope()
    }

    private func serialize(object: Any) throws -> String {
        let serialized = try JSONSerialization.data(
            withJSONObject: normalizeDates(in: object),
            options: [.fragmentsAllowed, .sortedKeys]
        )
        return try XCTUnwrap(String(data: serialized, encoding: .utf8))
    }

    private func normalizeDates(in object: Any) -> Any {
        switch object {
        case let date as Date:
            return ISO8601DateFormatter.string(
                from: date,
                timeZone: TimeZone(secondsFromGMT: 0) ?? .autoupdatingCurrent,
                formatOptions: [.withInternetDateTime]
            )
        case let dictionary as [String: Any]:
            return dictionary.mapValues { normalizeDates(in: $0) }
        case let array as [Any]:
            return array.map { normalizeDates(in: $0) }
        default:
            return object
        }
    }

    private func getCrashScope() -> SentryCrashScope {
        let jsonPointer = sentrycrash_scopesync_getScope()
        return jsonPointer.pointee
    }

    private func getScopeJson(getField: (SentryCrashScope) -> UnsafeMutablePointer<CChar>?) -> String? {
        let scopePointer = sentrycrash_scopesync_getScope()

        guard let charPointer = getField(scopePointer.pointee) else {
            return nil
        }

        return String(cString: charPointer)
    }

    private func assertOneCrumbSetToScope(crumb: Breadcrumb) throws {
        let expected = try serialize(object: crumb.serialize())

        let scope = sentrycrash_scopesync_getScope()

        XCTAssertEqual(1, scope.pointee.currentCrumb)

        let breadcrumbs = scope.pointee.breadcrumbs
        let breadcrumbJSON = String(cString: breadcrumbs?.pointee ?? UnsafeMutablePointer<CChar>.allocate(capacity: 0))

        XCTAssertEqual(expected, breadcrumbJSON)
    }

    private func assertEmptyScope() {
        let scope = getCrashScope()
        XCTAssertNil(scope.user)
        XCTAssertNil(scope.dist)
        XCTAssertNil(scope.context)
        XCTAssertNil(scope.environment)
        XCTAssertNil(scope.tags)
        XCTAssertNil(scope.extras)
        XCTAssertNil(scope.fingerprint)
        XCTAssertNil(scope.level)

        XCTAssertEqual(0, scope.currentCrumb)
        XCTAssertEqual(fixture.maxBreadcrumbs, UInt(scope.maxCrumbs))

        guard let breadcrumbs = scope.breadcrumbs else {
            XCTFail("Pointer to breadcrumbs is nil.")
            return
        }

        for i in 0..<Int(fixture.maxBreadcrumbs) {
            XCTAssertNil(breadcrumbs[i])
        }
    }
}
#endif
