@_spi(Private) @testable import Sentry
import XCTest

#if canImport(UIKit) && !SENTRY_NO_UI_FRAMEWORK && os(iOS)
import UIKit

final class SentryUIKitFeedbackFormPresenterTests: XCTestCase {

    func testPresent_whenNoPresenter_shouldReturnFalse() {
        let sut = SentryUIKitFeedbackFormPresenter(
            presentingViewControllerProvider: { nil },
            configuration: SentryUserFeedbackConfiguration(),
            formDelegate: TestFormDelegate()
        )

        XCTAssertFalse(sut.present(screenshot: nil))
    }

    func testPresent_whenPresenterIsNotAttachedToWindow_shouldReturnFalse() {
        let viewController = UIViewController()
        let sut = SentryUIKitFeedbackFormPresenter(
            presentingViewControllerProvider: { viewController },
            configuration: SentryUserFeedbackConfiguration(),
            formDelegate: TestFormDelegate()
        )

        XCTAssertFalse(sut.present(screenshot: nil))
    }

    func testPresent_whenPresenterIsAttachedToWindow_shouldPresentFormWithScreenshot() throws {
        let window = UIWindow(frame: UIScreen.main.bounds)
        let viewController = TestPresentingViewController()
        let config = SentryUserFeedbackConfiguration()
        config.animations = false
        let formDelegate = TestFormDelegate()
        let sut = SentryUIKitFeedbackFormPresenter(
            presentingViewControllerProvider: { viewController },
            configuration: config,
            formDelegate: formDelegate
        )
        let screenshot = UIImage()

        window.rootViewController = viewController
        window.makeKeyAndVisible()

        XCTAssertTrue(sut.present(screenshot: screenshot))
        let form = try XCTUnwrap(viewController.lastPresentedViewController as? SentryUserFeedbackFormController)
        XCTAssertIdentical(try XCTUnwrap(form.screenshot), screenshot)
        XCTAssertFalse(try XCTUnwrap(viewController.lastAnimated))

        withExtendedLifetime(window) { }
    }

    func testPresentationControllerDidDismiss_whenFormWasPresented_shouldNotifyDelegate() throws {
        let window = UIWindow(frame: UIScreen.main.bounds)
        let viewController = TestPresentingViewController()
        let config = SentryUserFeedbackConfiguration()
        config.animations = false
        let formDelegate = TestFormDelegate()
        let presenterDelegate = TestFeedbackFormPresenterDelegate()
        let sut = SentryUIKitFeedbackFormPresenter(
            presentingViewControllerProvider: { viewController },
            configuration: config,
            formDelegate: formDelegate
        )

        window.rootViewController = viewController
        window.makeKeyAndVisible()
        sut.delegate = presenterDelegate

        XCTAssertTrue(sut.present(screenshot: nil))
        let form = try XCTUnwrap(viewController.lastPresentedViewController as? SentryUserFeedbackFormController)
        let presentationController = UIPresentationController(
            presentedViewController: form,
            presenting: viewController
        )

        sut.presentationControllerDidDismiss(presentationController)

        XCTAssertEqual(presenterDelegate.dismissCount, 1)
        XCTAssertIdentical(presenterDelegate.lastDismissedPresenter, sut)

        withExtendedLifetime(window) { }
    }

    // MARK: - Helper Types

    private final class TestFeedbackFormPresenterDelegate: SentryFeedbackFormPresenterDelegate {
        private(set) var dismissCount = 0
        private(set) weak var lastDismissedPresenter: SentryFeedbackFormPresenter?

        func feedbackFormPresenterDidDismiss(_ presenter: SentryFeedbackFormPresenter) {
            dismissCount += 1
            lastDismissedPresenter = presenter
        }
    }

    private final class TestFormDelegate: NSObject, SentryUserFeedbackFormDelegate {
        private(set) var didAppearCount = 0
        private(set) var didFinish = false

        func didAppear() {
            didAppearCount += 1
        }

        func finished() {
            didFinish = true
        }
    }

    private final class TestPresentingViewController: UIViewController {
        private(set) var lastPresentedViewController: UIViewController?
        private(set) var lastAnimated: Bool?

        override func present(
            _ viewControllerToPresent: UIViewController,
            animated flag: Bool,
            completion: (() -> Void)? = nil
        ) {
            lastPresentedViewController = viewControllerToPresent
            lastAnimated = flag
            completion?()
        }
    }
}

#endif
