// swiftlint:disable missing_docs
import Foundation

#if (os(iOS) || os(tvOS)) && !SENTRY_NO_UI_FRAMEWORK

/// Provides screenshot capture for hybrid SDKs.
public struct SentryInternalScreenshotApi {

    typealias Dependencies = ScreenshotIntegrationProvider

    private let screenshotProvider: SentryScreenshotSource?

    init(dependencies: Dependencies) {
        self.screenshotProvider = dependencies.screenshotSource
    }

    /// Captures screenshots of all application windows.
    public func capture() -> [Data]? {
        screenshotProvider?.appScreenshotsData()
    }
}

#endif
// swiftlint:enable missing_docs
