@_implementationOnly import _SentryPrivate

#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK

/// An object that allows marking when the app launch is complete from the user's perspective.
///
/// Use this object to extend the app startup measurement to include additional initialization work
/// that happens after the first frame is rendered.
///
/// Call ``finish()`` when your app has finished launching and is ready for user interaction.
/// If ``finish()`` is not called, the app startup transaction will use the default end time
/// (first frame render).
///
/// - Important: This class must only be used from the main thread.
@objc public final class SentryAppLaunchTask: NSObject {
    private let onFinish: (Date) -> Void
    private var isFinished = false

    init(onFinish: @escaping (Date) -> Void) {
        self.onFinish = onFinish
        super.init()
    }

    /// Marks the app launch as complete.
    ///
    /// Call this method when your app has finished launching and is ready for user interaction.
    /// This extends the app startup span to include additional initialization work that happens
    /// after the first frame is rendered.
    ///
    /// Calling this method multiple times has no effect after the first call.
    ///
    /// - Important: This method must be called from the main thread.
    @objc public func finish() {
        // Must be called on main thread
        guard !isFinished else { return }
        isFinished = true
        let finishDate = SentryDependencyContainer.sharedInstance().dateProvider.date()
        onFinish(finishDate)
    }
}

#endif // (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
