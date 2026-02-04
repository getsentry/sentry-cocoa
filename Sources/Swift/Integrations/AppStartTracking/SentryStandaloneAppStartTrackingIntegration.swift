@_implementationOnly import _SentryPrivate

#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK

/// An integration that captures app startup time as a standalone transaction.
///
/// This integration creates an app start transaction independently of `ui.load` transactions,
/// allowing app startup time to be captured regardless of whether a view controller is loaded
/// within 5 seconds of app start.
final class SentryStandaloneAppStartTrackingIntegration: NSObject, SwiftIntegration {

    // MARK: - Static Properties

    private static var currentIntegration: SentryStandaloneAppStartTrackingIntegration?
    private static let integrationLock = NSLock()

    // MARK: - Instance Properties

    private var appStartMeasurement: SentryAppStartMeasurement?
    private var extendedLaunchTask: SentryAppLaunchTask?
    private var extendedLaunchFinishDate: Date?
    private var hasCreatedTransaction = false
    private let dateProvider: SentryCurrentDateProvider

    // MARK: - SwiftIntegration

    init?(with options: Options, dependencies: SentryDependencyContainer) {
        guard options.enableStandaloneAppStartTransaction else {
            SentrySDKLog.debug("Not enabling \(Self.name) because enableStandaloneAppStartTransaction is disabled.")
            return nil
        }

        guard options.isTracingEnabled else {
            SentrySDKLog.debug("Not enabling \(Self.name) because tracing is disabled.")
            return nil
        }

        self.dateProvider = dependencies.dateProvider

        super.init()

        // Store reference to this integration for the public API
        Self.integrationLock.lock()
        Self.currentIntegration = self
        Self.integrationLock.unlock()

        // Subscribe to app start measurement availability
        PrivateSentrySDKOnly.onAppStartMeasurementAvailable = { [weak self] measurement in
            self?.onAppStartMeasurementAvailable(measurement)
        }
    }

    func uninstall() {
        Self.integrationLock.lock()
        if Self.currentIntegration === self {
            Self.currentIntegration = nil
        }
        Self.integrationLock.unlock()

        PrivateSentrySDKOnly.onAppStartMeasurementAvailable = nil
    }

    static var name: String {
        "SentryStandaloneAppStartTrackingIntegration"
    }

    // MARK: - Public API Support

    /// Returns a task object that can be used to extend the app launch duration.
    /// Returns nil if the app start transaction has already been created.
    static func createExtendedAppLaunchTask() -> SentryAppLaunchTask? {
        integrationLock.lock()
        let integration = currentIntegration
        integrationLock.unlock()

        return integration?.createExtendedLaunchTask()
    }

    // MARK: - Private Methods

    private func onAppStartMeasurementAvailable(_ measurement: SentryAppStartMeasurement?) {
        // Called on main thread from SentryAppStartTracker
        guard let measurement = measurement else {
            SentrySDKLog.debug("App start measurement is nil, skipping standalone transaction.")
            return
        }

        self.appStartMeasurement = measurement

        // If there's no extended task, create the transaction immediately
        if extendedLaunchTask == nil {
            createAppStartTransaction(measurement: measurement, extendedEndDate: nil)
        } else {
            // Extended task exists, wait for it to finish
            // Check if it already finished before we received the measurement
            if let finishDate = extendedLaunchFinishDate {
                createAppStartTransaction(measurement: measurement, extendedEndDate: finishDate)
            } else {
                SentrySDKLog.debug("Waiting for extended app launch task to finish.")
            }
        }
    }

    private func createExtendedLaunchTask() -> SentryAppLaunchTask? {
        // Called on main thread from SentrySDK.extendedAppLaunchTask()
        // Don't create if transaction already created or task already exists
        guard !hasCreatedTransaction, extendedLaunchTask == nil else {
            SentrySDKLog.debug("Extended app launch task not created: transaction already created or task exists.")
            return nil
        }

        let task = SentryAppLaunchTask { [weak self] finishDate in
            self?.onExtendedLaunchTaskFinished(finishDate: finishDate)
        }
        extendedLaunchTask = task
        return task
    }

    private func onExtendedLaunchTaskFinished(finishDate: Date) {
        // Called on main thread from SentryAppLaunchTask.finish()
        extendedLaunchFinishDate = finishDate

        // If we already have the app start measurement, create the transaction now
        if let measurement = appStartMeasurement {
            createAppStartTransaction(measurement: measurement, extendedEndDate: finishDate)
        } else {
            SentrySDKLog.debug("Extended launch task finished but app start measurement not yet available.")
        }
    }

    private func createAppStartTransaction(measurement: SentryAppStartMeasurement, extendedEndDate: Date?) {
        // Called on main thread
        guard !hasCreatedTransaction else {
            SentrySDKLog.debug("App start transaction already created, skipping.")
            return
        }
        hasCreatedTransaction = true

        guard let operation = SentryAppStartSpanBuilder.operation(for: measurement.type),
              let measurementKey = SentryAppStartSpanBuilder.measurementKey(for: measurement.type) else {
            SentrySDKLog.debug("Unknown app start type, skipping standalone transaction.")
            return
        }

        // Calculate the end timestamp and duration
        let defaultEndDate = measurement.appStartTimestamp.addingTimeInterval(measurement.duration)
        let actualEndDate = extendedEndDate ?? defaultEndDate

        // Calculate final duration
        let finalDuration: TimeInterval
        if let extendedEndDate = extendedEndDate {
            finalDuration = extendedEndDate.timeIntervalSince(measurement.appStartTimestamp)
        } else {
            finalDuration = measurement.duration
        }

        // Create transaction context
        let transactionContext = TransactionContext(name: "app.start", operation: operation)
        transactionContext.origin = SentryTraceOriginAutoAppStart

        // Get the hub and create the tracer
        let hub = SentrySDKInternal.currentHub()

        let tracer = hub.startTransaction(
            transactionContext: transactionContext,
            bindToScope: false,
            customSamplingContext: [:]
        )

        // Set the start timestamp to the app start timestamp
        tracer.startTimestamp = measurement.appStartTimestamp

        // Build the app start child spans using shared helper
        SentryAppStartSpanBuilder.buildSpans(on: tracer, measurement: measurement, operation: operation, extendedEndDate: extendedEndDate)

        // Set the app start measurement
        tracer.setMeasurement(name: measurementKey, value: NSNumber(value: finalDuration * 1000), unit: MeasurementUnitDuration.millisecond)

        // Set app start type context
        let appStartType = SentryAppStartSpanBuilder.appStartTypeString(for: measurement)
        tracer.setData(value: appStartType, key: "app_start_type")

        // Set timestamp and finish the transaction
        tracer.timestamp = actualEndDate
        tracer.finish(status: SentrySpanStatus.ok)

        SentrySDKLog.debug("Created standalone app start transaction with duration: \(finalDuration * 1000)ms")
    }
}

#endif // (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
