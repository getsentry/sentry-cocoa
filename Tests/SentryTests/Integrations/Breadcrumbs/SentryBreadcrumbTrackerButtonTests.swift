@_spi(Private) @testable import Sentry
import XCTest

#if os(iOS) || os(tvOS)
final class SentryBreadcrumbTrackerButtonTests: XCTestCase {
    @available(iOS 15.0, tvOS 15.0, *)
    func testExtractData_whenConfigurationUsesSeparateRenderedLabel_shouldAddTitleOnce() {
        // -- Arrange --
        let view = UIView()
        var configuration = UIButton.Configuration.plain()
        configuration.title = "Configured title"
        let button = UIButton(configuration: configuration)
        XCTAssertNotNil(button.titleLabel)
        let renderedLabel = UILabel()
        renderedLabel.text = "Configured title"
        button.addSubview(renderedLabel)
        view.addSubview(button)

        // -- Act --
        let data = SentryBreadcrumbTracker.extractData(from: view, includeAccessibilityIdentifier: true)

        // -- Assert --
        XCTAssertEqual(data["label"] as? String, "Configured title")
    }
}
#endif
