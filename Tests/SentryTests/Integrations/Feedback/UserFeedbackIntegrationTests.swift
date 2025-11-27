@_spi(Private) @testable import Sentry
import XCTest

#if os(iOS)

final class UserFeedbackIntegrationTests: XCTestCase {
    
    static private var optionsWithFeedback: Options {
        let options = Options()
        options.configureUserFeedback = { _ in }
        return options
    }
    
    static private var optionsWithoutFeedback: Options {
        return Options()
    }
    
    static private var screenshotSource: SentryScreenshotSource {
        let viewRenderer = SentryDefaultViewRenderer()
        let photographer = SentryViewPhotographer(
           renderer: viewRenderer,
           redactOptions: Options().screenshot,
            enableMaskRendererV2: false)
        return SentryScreenshotSource(photographer: photographer)
    }
    
    private struct MockDependencies: ScreenshotSourceProvider {
        let screenshotSource: SentryScreenshotSource?
    }
    
    func testUsesCorrectName() {
        XCTAssertEqual(UserFeedbackIntegration<MockDependencies>.name, "SentryUserFeedbackIntegration")
    }
    
    func testInitializerFailsWhenNoScreenshotSource() {
        let integration = UserFeedbackIntegration(with: Self.optionsWithFeedback, dependencies: MockDependencies(screenshotSource: nil))
        XCTAssertNil(integration)
    }
    
    func testInitializerSucceedsWhenScreenshotSourceIsPresent() {
        let integration = UserFeedbackIntegration(with: Self.optionsWithFeedback, dependencies: MockDependencies(screenshotSource: Self.screenshotSource))
        XCTAssertNotNil(integration)
    }
    
    func testInitializerFailsWhenFeedbackNotConfigured() {
        let integration = UserFeedbackIntegration(with: Self.optionsWithoutFeedback, dependencies: MockDependencies(screenshotSource: nil))
        XCTAssertNil(integration)
    }
}

#endif
