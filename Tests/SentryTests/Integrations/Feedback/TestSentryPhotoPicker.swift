import Foundation

#if os(iOS) && !SENTRY_NO_UIKIT
@testable import Sentry

// the iOS photo picker UI doesn't play nicely with XCUITest, so we need to mock it
@available(iOS 13.0, *)
class TestSentryPhotoPicker: SentryPhotoPicker {
    override func display(config: SentryUserFeedbackConfiguration, presenter: UIViewController & SentryPhotoPickerDelegate) {
        presenter.chose(image: UIImage(), accessibilityInfo: "test image accessibility info")
    }
}

#endif // os(iOS) && !SENTRY_NO_UIKIT
