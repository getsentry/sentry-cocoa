@_spi(Private) @testable import Sentry
import XCTest

#if os(iOS)

final class UserFeedbackIntegrationTests: XCTestCase {
    
    static private var optionsWithFeedback: Options {
        let options = Options()
        options.configureUserFeedback = { _ in }
        return options
    }
    
    private struct TestDependencies: ScreenshotSourceProvider {
        let screenshotSource: SentryScreenshotSource?
    }
    
    func testUsesCorrectName() {
        XCTAssertEqual(UserFeedbackIntegration<TestDependencies>.name, "SentryUserFeedbackIntegration")
    }
    
    func testInitializerFailsWhenNoScreenshotSource() {
        let integration = UserFeedbackIntegration(with: Self.optionsWithFeedback, dependencies: TestDependencies(screenshotSource: nil))
        XCTAssertNil(integration)
    }
    
    func testInitializerSucceedsWhenScreenshotSourceIsPresent() {
        let viewRenderer = SentryDefaultViewRenderer()
        let photographer = SentryViewPhotographer(
           renderer: viewRenderer,
           redactOptions: Options().screenshot,
            enableMaskRendererV2: false)
        let screenshotSource = SentryScreenshotSource(photographer: photographer)
        let integration = UserFeedbackIntegration(with: Self.optionsWithFeedback, dependencies: TestDependencies(screenshotSource: screenshotSource))
        XCTAssertNotNil(integration)
    }
    
    func testInitializerFailsWhenFeedbackNotConfigured() {
        let integration = UserFeedbackIntegration(with: Options(), dependencies: TestDependencies(screenshotSource: nil))
        XCTAssertNil(integration)
    }
}

#endif
