@_implementationOnly import _SentryPrivate

#if os(iOS) && !SENTRY_NO_UI_FRAMEWORK

protocol ScreenshotSourceProvider {
    var screenshotSource: SentryScreenshotSource? { get }
}

final class UserFeedbackIntegration<Dependencies: ScreenshotSourceProvider>: NSObject, SwiftIntegration {

    let driver: SentryUserFeedbackIntegrationDriver

    init?(with options: Options, dependencies: Dependencies) {
        guard let configuration = options.userFeedbackConfiguration else {
            return nil
        }
        
        // The screenshot source is coupled to the options, but due to the dependency container being
        // tightly to the options anyways, it was decided to not pass it to the container.
        guard let screenshotSource = dependencies.screenshotSource else {
            return nil
        }

        driver = SentryUserFeedbackIntegrationDriver(configuration: configuration, screenshotSource: screenshotSource) { feedback in
            SentrySDK.capture(feedback: feedback)
        }
    }

    func uninstall() { /* Empty on purpose. Nothing to uninstall. */ }
    
    static var name: String {
        "SentryUserFeedbackIntegration"
    }
}

#endif
