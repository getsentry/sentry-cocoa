// swiftlint:disable missing_docs
#if canImport(UIKit) && !SENTRY_NO_UI_FRAMEWORK
#if os(iOS) || os(tvOS) || os(visionOS)

internal import _SentryPrivate
import UIKit

/// On visionOS, screenshots capture only the content of UIKit windows (2D Scenes).
/// Content rendered in immersive spaces or volumetric windows via RealityKit is not
/// included because the UIKit drawing APIs operate on the 2D view layer and have no
/// access to the compositor's 3D scene graph.
@objcMembers
@_spi(Private) public class SentryScreenshotSource: NSObject {
    private let photographer: SentryViewPhotographer

    public override convenience init() {
        // We need to provide a init method without parameters for Obj-C compatibility.
        // However, we want to force users to provide a photographer.
        // `assertionFailure` will not crash the app in release builds, but at least
        // it notifies the developer during testing and development.
        assertionFailure("Use init(photographer:) instead")
        self.init(photographer: SentryViewPhotographer(
            renderer: SentryDefaultViewRenderer(),
            redactOptions: SentryRedactDefaultOptions(),
            enableMaskRendererV2: false,
            dateProvider: SentryDependencyContainer.sharedInstance().dateProvider
        ))
    }

    public init(photographer: SentryViewPhotographer) {
        self.photographer = photographer
        super.init()
    }

    /// Get a screenshot of every open window in the app.
    /// - Returns: An array of UIImage instances.
    public func appScreenshotsFromMainThread() -> [UIImage] {
        var result: [UIImage] = []

        let takeScreenShot = { result = self.appScreenshots() }

        SentryDependencyContainerSwiftHelper.dispatchSync(onMainQueue: takeScreenShot)

        return result
    }

    /// Get a screenshot of every open window in the app.
    /// - Returns: An array of Data instances containing PNG images.
    public func appScreenshotDatasFromMainThread() -> [Data] {
        var result: [Data] = []

        let takeScreenShot = { result = self.appScreenshotsData() }

        SentryDependencyContainerSwiftHelper.dispatchSync(onMainQueue: takeScreenShot)

        return result
    }

    /// Save the current app screen shots in the given directory.
    /// If an app has more than one screen, one image for each screen will be saved.
    /// - Parameter imagesDirectoryPath: The path where the images should be saved.
    public func saveScreenShots(_ imagesDirectoryPath: String) {
        // This function does not dispatch the screenshot to the main thread.
        // The caller should be aware of that.
        // We did it this way because we use this function to save screenshots
        // during signal handling, and if we dispatch it to the main thread,
        // that is probably blocked by the crash event, we freeze the application.
#if SDK_V10
        sentrykscrash_attachments_log("saveScreenShots: enter")
#endif
        // Crash-time: do not hop to main. Other threads are suspended, so
        // `windows()` times out empty (10ms). SentryCrash read windows on this thread.
        let windows = SentryDependencyContainer.sharedInstance().application()?.collectWindowsOnCurrentThread() ?? []
#if SDK_V10
        sentrykscrash_attachments_log_i("saveScreenShots: windows", Int32(windows.count))
#endif
        let screenshotData = pngData(from: screenshots(from: windows))
#if SDK_V10
        sentrykscrash_attachments_log_i("saveScreenShots: png count", Int32(screenshotData.count))
#endif

        for (index, data) in screenshotData.enumerated() {
            let name = index == 0 ? "screenshot.png" : "screenshot-\(index + 1).png"
            let fileName = (imagesDirectoryPath as NSString).appendingPathComponent(name)
            do {
                try data.write(to: URL(fileURLWithPath: fileName), options: .atomic)
#if SDK_V10
                sentrykscrash_attachments_log_i("saveScreenShots: wrote png bytes", Int32(data.count))
#endif
            } catch {
#if SDK_V10
                sentrykscrash_attachments_log("saveScreenShots: png write failed")
#endif
            }
        }
#if SDK_V10
        sentrykscrash_attachments_log("saveScreenShots: return")
#endif
    }

    public func appScreenshots() -> [UIImage] {
        screenshots(from: SentryDependencyContainerSwiftHelper.windows() ?? [])
    }

    public func appScreenshotsData() -> [Data] {
        pngData(from: appScreenshots())
    }

    private func screenshots(from windows: [UIWindow]) -> [UIImage] {
        var result: [UIImage] = []
        result.reserveCapacity(windows.count)

        for window in windows {
            let size = window.frame.size
            if size.width == 0 || size.height == 0 {
                continue
            }

            let img = photographer.image(view: window)
            if img.size.width > 0 && img.size.height > 0 {
                result.append(img)
            }
        }
        return result
    }

    private func pngData(from screenshots: [UIImage]) -> [Data] {
        var result: [Data] = []
        result.reserveCapacity(screenshots.count)

        for screenshot in screenshots {
            if screenshot.size.width > 0 && screenshot.size.height > 0 {
                if let data = screenshot.pngData(), !data.isEmpty {
                    result.append(data)
                }
            }
        }
        return result
    }
}

#endif // os(iOS) || os(tvOS)
#endif // canImport(UIKit) && !SENTRY_NO_UI_FRAMEWORK
// swiftlint:enable missing_docs
