@_spi(Private) @testable import Sentry
import XCTest

#if canImport(SwiftUI) && canImport(UIKit) && !SENTRY_NO_UI_FRAMEWORK && os(iOS)
import SwiftUI
import UIKit

final class SentrySwiftUIFeedbackFormPresenterTests: XCTestCase {

    func testPresent_whenAttached_shouldSetBindingAndScreenshot() throws {
        var isPresented = false
        let binding = Binding<Bool>(
            get: { isPresented },
            set: { isPresented = $0 }
        )
        let sut = SentrySwiftUIFeedbackFormPresenter()
        let screenshot = UIImage()

        sut.update(isPresented: binding)

        XCTAssertTrue(sut.present(screenshot: screenshot))

        XCTAssertTrue(isPresented)
        XCTAssertIdentical(try XCTUnwrap(sut.activeScreenshot), screenshot)
    }

    func testPresent_whenAlreadyPresented_shouldReturnFalse() {
        var isPresented = true
        let binding = Binding<Bool>(
            get: { isPresented },
            set: { isPresented = $0 }
        )
        let sut = SentrySwiftUIFeedbackFormPresenter()

        sut.update(isPresented: binding)

        XCTAssertFalse(sut.present(screenshot: nil))
    }

    func testDismiss_whenPresented_shouldClearBindingWithoutNotifyingDelegate() {
        var isPresented = false
        let binding = Binding<Bool>(
            get: { isPresented },
            set: { isPresented = $0 }
        )
        let delegate = TestFeedbackFormPresenterDelegate()
        let sut = SentrySwiftUIFeedbackFormPresenter()

        sut.delegate = delegate
        sut.update(isPresented: binding)
        XCTAssertTrue(sut.present(screenshot: nil))

        sut.dismiss()

        XCTAssertFalse(isPresented)
        XCTAssertEqual(delegate.dismissCount, 0)
    }

    func testSheetDidDismiss_whenPresented_shouldNotifyDelegateOnceAndClearScreenshot() throws {
        var isPresented = false
        let binding = Binding<Bool>(
            get: { isPresented },
            set: { isPresented = $0 }
        )
        let delegate = TestFeedbackFormPresenterDelegate()
        let sut = SentrySwiftUIFeedbackFormPresenter()
        let screenshot = UIImage()

        sut.delegate = delegate
        sut.update(isPresented: binding)
        XCTAssertTrue(sut.present(screenshot: screenshot))

        sut.sheetDidDismiss()
        sut.sheetDidDismiss()

        XCTAssertEqual(delegate.dismissCount, 1)
        XCTAssertIdentical(delegate.lastDismissedPresenter, sut)
        XCTAssertNil(sut.activeScreenshot)
    }

    func testPresent_whenUnattached_shouldReturnFalse() {
        let sut = SentrySwiftUIFeedbackFormPresenter()

        XCTAssertFalse(sut.present(screenshot: nil))
        XCTAssertNil(sut.activeScreenshot)
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
}

#endif
