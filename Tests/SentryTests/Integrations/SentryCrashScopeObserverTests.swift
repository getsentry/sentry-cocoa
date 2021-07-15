import XCTest

class SentryCrashScopeObserverTests: XCTestCase {
    
    private class Fixture {
        let dist = "dist"
        let environment = "environment"
        let tags = ["tag": "tag", "tag1": "tag1"]
        let extras = ["extra": [1, 2], "extra2": "tag1"] as [String: Any]
        let fingerprint = ["a", "b", "c"]
        let maxBreadcrumbs = 10
        
        var sut: SentryCrashScopeObserver {
            return SentryCrashScopeObserver(maxBreadcrumbs: maxBreadcrumbs)
        }
    }
    
    private let fixture = Fixture()
    
    override func setUp() {
        sentryscopesync_reset()
        SentryCrash.sharedInstance().userInfo = nil
    }
    
    override func tearDown() {
        sentryscopesync_reset()
        SentryCrash.sharedInstance().userInfo = nil
    }

    func testUser() {
        let sut = fixture.sut
        let user = TestData.user
        sut.setUser(user)
        
        let expected = serialize(object: user.serialize())
        
        XCTAssertEqual(expected, getScopeJson { $0.userJSON })
    }

    func testUser_setToNil() {
        let sut = fixture.sut
        sut.setUser(TestData.user)
        sut.setUser(nil)

        XCTAssertNil(getScopeJson { $0.userJSON })
    }
    
    func testLevel() {
        let sut = fixture.sut
        let level = SentryLevel.fatal
        sut.setLevel(level)

        XCTAssertEqual("\"fatal\"", getScopeJson { $0.levelJSON })
    }

    func testLevel_setToNone() {
        let sut = fixture.sut
        sut.setLevel(SentryLevel.fatal)
        sut.setLevel(SentryLevel.none)

        XCTAssertNil(getScopeJson { $0.levelJSON })
    }

    func testDist() {
        let sut = fixture.sut
        sut.setDist(fixture.dist)

        let expected = serialize(object: fixture.dist)

        XCTAssertEqual(expected, getScopeJson { $0.distJSON })
    }

    func testDist_setToNil() {
        let sut = fixture.sut
        sut.setDist(fixture.dist)
        sut.setDist(nil)

        XCTAssertNil(getScopeJson { $0.distJSON })
    }

    func testEnvironment() {
        let sut = fixture.sut
        sut.setEnvironment(fixture.environment)

        let expected = serialize(object: fixture.environment)

        XCTAssertEqual(expected, getScopeJson { $0.environmentJSON })
    }

    func testEnvironment_setToNil() {
        let sut = fixture.sut
        sut.setEnvironment(fixture.environment)
        sut.setEnvironment(nil)

        XCTAssertNil(getScopeJson { $0.environmentJSON })
    }

    func testContext() {
        let sut = fixture.sut
        sut.setContext(TestData.context)

        let expected = serialize(object: TestData.context)

        XCTAssertEqual(expected, getScopeJson { $0.contextJSON })
    }

    func testContext_setToNil() {
        let scope = Scope()
        let sut = fixture.sut
        scope.add(sut)
        TestData.setContext(scope)
        sut.setContext(nil)

        XCTAssertNil(getScopeJson { $0.contextJSON })
    }

    func testContext_setEmptyDict() {
        let scope = Scope()
        let sut = fixture.sut
        scope.add(sut)
        TestData.setContext(scope)
        sut.setContext([:])

        XCTAssertNil(getScopeJson { $0.contextJSON })
    }

    func testFingerprint() {
        let sut = fixture.sut
        sut.setFingerprint(fixture.fingerprint)

        let expected = serialize(object: fixture.fingerprint)

        XCTAssertEqual(expected, getScopeJson { $0.fingerprintJSON })
    }

    func testFingerprint_SetToNil() {
        let sut = fixture.sut
        sut.setFingerprint(fixture.fingerprint)
        sut.setFingerprint(nil)

        XCTAssertNil(getScopeJson { $0.fingerprintJSON })
    }

    func testFingerprint_SetToEmptyArray() {
        let sut = fixture.sut
        sut.setFingerprint(fixture.fingerprint)
        sut.setFingerprint([])

        XCTAssertNil(getScopeJson { $0.fingerprintJSON })
    }

    func testExtra() {
        let sut = fixture.sut
        sut.setExtras(fixture.extras)

        let expected = serialize(object: fixture.extras)

        XCTAssertEqual(expected, getScopeJson { $0.extrasJSON })
    }

    func testExtra_SetToNil() {
        let sut = fixture.sut
        sut.setExtras(fixture.extras)
        sut.setExtras(nil)

        XCTAssertNil(getScopeJson { $0.extrasJSON })
    }

    func testExtra_SetToEmptyDict() {
        let sut = fixture.sut
        sut.setExtras(fixture.extras)
        sut.setExtras([:])

        XCTAssertNil(getScopeJson { $0.extrasJSON })
    }

    func testTags() {
        let sut = fixture.sut
        sut.setTags(fixture.tags)

        let expected = serialize(object: fixture.tags)

        XCTAssertEqual(expected, getScopeJson { $0.tagsJSON })
    }

    func testTags_SetToNil() {
        let sut = fixture.sut
        sut.setTags(fixture.tags)
        sut.setTags(nil)

        XCTAssertNil(getScopeJson { $0.tagsJSON })
    }

    func testTags_SetToEmptyDict() {
        let sut = fixture.sut
        sut.setTags(fixture.tags)
        sut.setTags([:])

        XCTAssertNil(getScopeJson { $0.tagsJSON })
    }

    func testAddCrumb() {
        let sut = fixture.sut
        let crumb = TestData.crumb
        sut.add(crumb)
        
        assertOneCrumbSetToScope(crumb: crumb)
    }
    
    func testAddCrumbWithoutConfigure_DoesNotCrash() {
        sentryscopesync_addBreadcrumb("")
    }
    
    func testCallConfigureCrumbTwice() {
        let sut = fixture.sut
        let crumb = TestData.crumb
        sut.add(crumb)
        
        sentryscopesync_configureBreadcrumbs(fixture.maxBreadcrumbs)
        
        let scope = sentryscopesync_getScope()
        XCTAssertEqual(0, scope?.pointee.currentCrumb)
        
        sut.add(crumb)
        assertOneCrumbSetToScope(crumb: crumb)
    }

    func testAddCrumb_MoreThanMaxBreadcrumbs() {
        let sut = fixture.sut
        
        var crumbs: [Breadcrumb] = []
        for i in 0...fixture.maxBreadcrumbs {
            let crumb = TestData.crumb
            crumb.message = "\(i)"
            sut.add(crumb)
            crumbs.append(crumb)
        }
        crumbs.removeFirst()

        let scope = sentryscopesync_getScope()
        
        XCTAssertEqual(1, scope?.pointee.currentCrumb)
        
        guard let breadcrumbs = scope?.pointee.breadcrumbs else {
            XCTFail("Pointer to breadcrumbs is nil.")
            return
        }
        
        // Breadcrumbs are stored with a ring buffer. Therefore,
        // we need to start where the current crumb is
        var i = scope?.pointee.currentCrumb ?? 0
        var crumbPointer = breadcrumbs[i]
        for crumb in crumbs {
            let scopeCrumbJSON = String(cString: crumbPointer ?? UnsafeMutablePointer<CChar>.allocate(capacity: 0))
            
            XCTAssertEqual(serialize(object: crumb.serialize()), scopeCrumbJSON)
            
            i = (i + 1) % fixture.maxBreadcrumbs
            crumbPointer = breadcrumbs[i]
        }
    }

    func testClear() {
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
        sut.add(TestData.crumb)
        
        sut.clear()
        
       assertEmptyScope()
    }
    
    func testEmptyScope() {
        // First, we need to configure the CScope
        XCTAssertNotNil(fixture.sut)
        
        assertEmptyScope()
    }
    
    private func serialize(object: Any) -> String {
        let serialized = try! SentryCrashJSONCodec.encode(object, options: SentryCrashJSONEncodeOptionSorted)
        return String(data: serialized, encoding: .utf8) ?? ""
    }
    
    private func getCrashScope() -> SentryCrashScope {
        let jsonPointer = sentryscopesync_getScope()
        return jsonPointer!.pointee
    }
    
    private func getScopeJson(getField: (SentryCrashScope)-> UnsafeMutablePointer<CChar>?) -> String? {
        guard let scopePointer = sentryscopesync_getScope() else {
            return nil
        }

        guard let charPointer = getField(scopePointer.pointee) else {
            return nil
        }
        
        return String(cString: charPointer)
    }
    
    private func assertOneCrumbSetToScope(crumb: Breadcrumb) {
        let expected = serialize(object: crumb.serialize())
        
        let scope = sentryscopesync_getScope()
        
        XCTAssertEqual(1, scope?.pointee.currentCrumb)
        
        let breadcrumbs = scope?.pointee.breadcrumbs
        let breadcrumbJSON = String(cString: breadcrumbs?.pointee ?? UnsafeMutablePointer<CChar>.allocate(capacity: 0))
        
        XCTAssertEqual(expected, breadcrumbJSON)
    }
    
    private func assertEmptyScope() {
        let scope = getCrashScope()
        XCTAssertNil(scope.userJSON)
        XCTAssertNil(scope.distJSON)
        XCTAssertNil(scope.contextJSON)
        XCTAssertNil(scope.environmentJSON)
        XCTAssertNil(scope.tagsJSON)
        XCTAssertNil(scope.extrasJSON)
        XCTAssertNil(scope.fingerprintJSON)
        XCTAssertNil(scope.levelJSON)
        
        XCTAssertEqual(0, scope.currentCrumb)
        XCTAssertEqual(fixture.maxBreadcrumbs, scope.maxCrumbs)
        
        guard let breadcrumbs = scope.breadcrumbs else {
            XCTFail("Pointer to breadcrumbs is nil.")
            return
        }

        for i in 0..<fixture.maxBreadcrumbs {
            XCTAssertNil(breadcrumbs[i])
        }
    }
}
