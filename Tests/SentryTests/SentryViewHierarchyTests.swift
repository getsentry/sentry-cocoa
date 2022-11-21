import XCTest

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
class SentryViewHierarchyTests: SentryBaseUnitTest {
    private class Fixture {

        let uiApplication = TestSentryUIApplication()

        var sut: SentryViewHierarchy {
            return SentryViewHierarchy()
        }
    }

    private var fixture: Fixture!

    override func setUp() {
        super.setUp()
        fixture = Fixture()
        SentryDependencyContainer.sharedInstance().application = fixture.uiApplication
    }

    func test_Draw_Each_Window() {
        let firstWindow = UIWindow(frame: CGRect(x: 0, y: 0, width: 10, height: 10))
        let secondWindow = UIWindow(frame: CGRect(x: 0, y: 0, width: 10, height: 10))

        fixture.uiApplication.windows = [firstWindow, secondWindow]

        let descriptions = self.fixture.sut.fetch()

        XCTAssertEqual(descriptions.count, 2)
    }

    func test_Draw_ViewHierarchy() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 10, height: 10))

        fixture.uiApplication.windows = [window]

        let descriptions = self.fixture.sut.fetch()

        XCTAssertTrue(descriptions[0].starts(with: "<UIWindow: "))
    }

    class TestSentryUIApplication: SentryUIApplication {
        private var _windows: [UIWindow]?

        override var windows: [UIWindow]? {
            get {
                return _windows
            }
            set {
                _windows = newValue
            }
        }
    }
}
#endif
