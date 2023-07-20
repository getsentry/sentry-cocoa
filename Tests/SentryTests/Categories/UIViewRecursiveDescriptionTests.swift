@testable import Sentry
import XCTest

#if (os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)) && SENTRY_USE_UIKIT
class UIViewRecursiveDescriptionTests: XCTestCase {
    func testSimpleView() {
        let view = UIView()
        let description = view.sentry_recursiveViewHierarchyDescription()
        XCTAssertEqual(description, view.description + "\n")
    }

    func testViewHierarchy() {
        let view = UIView()
        let subview = UIView()
        let button = UIButton(frame: .init(x: 0, y: 0, width: 100, height: 100))
        subview.addSubview(button)
        view.addSubview(subview)

        let description = view.sentry_recursiveViewHierarchyDescription()

        let expected = [
            view.description,
            "   | " + subview.description,
            "   |    | " + button.description
        ]

        XCTAssertEqual(description, expected.joined(separator: "\n") + "\n")
    }
}
#endif // (os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)) && SENTRY_USE_UIKIT
