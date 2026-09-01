// swiftlint:disable missing_docs
import Foundation

#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK

/// Provides screenshot capture for hybrid SDKs.
public struct SentryInternalScreenshotApi {

#if os(iOS) || os(tvOS)
    typealias Dependencies = ScreenshotIntegrationProvider

    private let screenshotProvider: SentryScreenshotSource?

    init(dependencies: Dependencies) {
        self.screenshotProvider = dependencies.screenshotSource
    }
#else
    init(dependencies: Any) { }
#endif

    /// Captures screenshots of all application windows.
    public func capture() -> [Data]? {
#if os(iOS) || os(tvOS)
        screenshotProvider?.appScreenshotsData()
#else
        nil
#endif
    }
}

#endif
// swiftlint:enable missing_docs
