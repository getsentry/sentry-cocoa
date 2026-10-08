internal import _SentryPrivate
import Foundation

#if os(iOS) || os(macOS)

/// Keys of the launch profile configuration that is persisted to disk for the next launch.
enum SentryLaunchProfileConfigKey {
    static let tracesSampleRate = "traces"
    static let tracesSampleRand = "traces.sample_rand"
    static let profilesSampleRate = "profiles"
    static let profilesSampleRand = "profiles.sample_rand"
    static let continuousProfilingV2Lifecycle = "continuous-profiling-v2-lifecycle"
    static let waitForFullDisplay = "launch-profile.wait-for-full-display"
}

/// Starts a profile when the app launches, based on the configuration the previous launch
/// persisted, and persists the configuration for the next launch.
///
/// SentryTracer and SentryHubInternal belong to _SentryPrivate and cannot appear in the exported
/// Swift interface, so the Objective-C entry points take `AnyObject`. Internal Swift callers use
/// the typed members.
@_spi(Private) @objc public final class SentryLaunchProfiling: NSObject {

    private struct State {
        var isTracingAppLaunch = false
        var launchTracer: SentryTracer?
    }

    private struct LaunchProfileDecision {
        /// Only needed for continuous profiling v2 with trace lifecycle.
        let tracesDecision: SentrySamplerDecision?
        let profilesDecision: SentrySamplerDecision
    }

    private static let state = SentryMutex(State())

    // This is called from SentryProfiler.load, but in the future we may expose access directly to
    // customers, and we'll want to ensure it only runs once.
    private static let startLaunchProfileOnce: Void = {
        startLaunchProfileWithoutDeduplication()
    }()

    /// Whether or not the profiler started with the app launch. With trace profiling, this means
    /// there is a tracer managing the profile that will eventually need to be stopped and either
    /// discarded (in the case of auto performance transactions) or also transmitted. With
    /// continuous profiling, this indicates whether or not the profiler that's currently running
    /// was started from app launch, or later with a manual profiler start from the SDK consumer.
    @objc public static var isTracingAppLaunch: Bool {
        get { state.withLock { $0.isTracingAppLaunch } }
        set { state.withLock { $0.isTracingAppLaunch = newValue } }
    }

    static var launchTracer: SentryTracer? {
        get { state.withLock { $0.launchTracer } }
        set { state.withLock { $0.launchTracer = newValue } }
    }

    /// The tracer managing the launch profile, if there is one.
    @objc(launchTracer) public static var launchTracerObject: AnyObject? {
        launchTracer
    }

    /// Starts the launch profile if the previous launch configured one. Only the first call has an
    /// effect.
    @objc public static func startLaunchProfile() {
        _ = startLaunchProfileOnce
    }

    /// Stop a launch tracer in order to stop the associated profiler. Must attach a hub, since
    /// there isn't yet one when we start the launch tracer.
    /// - Note: If the hub is nil, the tracer/profile will be discarded. This normally should always
    /// have a valid hub, but tests may not have one and call this with nil instead.
    @objc(stopAndDiscardLaunchProfileTracerWithHub:)
    public static func stopAndDiscardLaunchProfileTracer(withHub hub: AnyObject?) {
        stopAndDiscardLaunchProfileTracer(hub: hub as? SentryHubInternal)
    }

    static func stopAndDiscardLaunchProfileTracer(hub: SentryHubInternal?) {
        SentrySDKLog.debug("Finishing launch tracer.")

        // Finishing the tracer reads the launch state, so the tracer must stay set until it is
        // finished and the lock must not be held meanwhile.
        if let tracer = launchTracer {
            tracer.hub = hub
            tracer.finish()
        }
        sentry_setProfileConfiguration(nil)
        state.withLock {
            $0.isTracingAppLaunch = false
            $0.launchTracer = nil
        }
    }

    /// Write a file to disk containing profile configuration options. The presence of this file
    /// will let the profiler know to start on the app launch, and the sample rates contained will
    /// help thread sampling decisions through to SentryHub later when it needs to start a
    /// transaction for the profile to be attached to.
    @objc(configureLaunchProfilingForNextLaunchWithOptions:)
    public static func configureLaunchProfilingForNextLaunch(_ options: Options) {
        SentryDependencyContainer.sharedInstance().dispatchQueueWrapper.dispatchAsync {
            guard let profiling = options.profiling, let decision = launchProfileDecision(for: options) else {
                SentrySDKLog.debug("Removing launch profile config file.")
                removeAppLaunchProfilingConfigFile()
                return
            }

            let configDict = NSMutableDictionary()
            configDict[SentryLaunchProfileConfigKey.waitForFullDisplay] = NSNumber(value: options.enableTimeToFullDisplayTracing)
            SentrySDKLog.debug("Configuring continuous launch profile v2.")
            configDict[SentryLaunchProfileConfigKey.continuousProfilingV2Lifecycle] = NSNumber(value: profiling.lifecycle.rawValue)
            if profiling.lifecycle == .trace {
                configDict[SentryLaunchProfileConfigKey.tracesSampleRate] = decision.tracesDecision?.sampleRate
                configDict[SentryLaunchProfileConfigKey.tracesSampleRand] = decision.tracesDecision?.sampleRand
            }
            configDict[SentryLaunchProfileConfigKey.profilesSampleRate] = decision.profilesDecision.sampleRate
            configDict[SentryLaunchProfileConfigKey.profilesSampleRand] = decision.profilesDecision.sampleRand
            writeAppLaunchProfilingConfigFile(configDict)
        }
    }

    static func willProfileNextLaunch(_ options: Options) -> Bool {
        return launchProfileDecision(for: options) != nil
    }

    /// Contains the logic to start a launch profile. Separate from `startLaunchProfile`, because
    /// that only runs once, when `SentryProfiler.load` is called, so tests can't run it again.
    static func startLaunchProfileWithoutDeduplication() {
        guard appLaunchProfileConfigFileExists() else {
            SentrySDKLog.debug("No launch profile config exists, will not profile launch.")
            return
        }

        // The config should only apply to a single launch, so we remove the file whether or not
        // starting the launch profile succeeds. Subsequent launches must be configured by
        // subsequent calls to SentrySDK.start(options:); if that is not called, either deliberately
        // by SDK consumers or due to a problem before it can run, then we won't reuse the config.
        // In the worst case, the launch profile itself is the root cause of such a cycle, so this
        // mitigates that and other possibilities.
        defer { removeAppLaunchProfilingConfigFile() }

#if DEBUG
        // Quick and dirty way to get debug logging this early in the process run. This will get
        // overwritten once SentrySDK.start(options:) is called according to the values of
        // Options.debug and Options.diagnosticLevel.
        SentrySDKLogSupport.configure(true, diagnosticLevel: .debug)
#endif // DEBUG

        let launchConfig = sentry_persistedLaunchProfileConfigurationOptions() ?? [:]

        guard let decision = profileSampleDecision(launchConfig) else {
            SentrySDKLog.debug("Couldn't hydrate the persisted sample decision.")
            return
        }

        guard let shouldWaitForFullDisplayValue = launchConfig[SentryLaunchProfileConfigKey.waitForFullDisplay] else {
            SentrySDKLog.debug("Received a nil configured launch profile value indicating whether or not the profile should be finished on full display or SDK start, cannot know when to stop the profile, will not start this launch.")
            return
        }
        let shouldWaitForFullDisplay = shouldWaitForFullDisplayValue.boolValue

        SentrySDKLog.debug("Starting continuous launch profile v2.")
        guard let lifecycleValue = launchConfig[SentryLaunchProfileConfigKey.continuousProfilingV2Lifecycle] else {
            SentrySDKLog.error("Missing expected launch profile config parameter for lifecycle. Will not proceed with launch profile.")
            return
        }

        if lifecycleValue.intValue == SentryProfileOptions.SentryProfileLifecycle.manual.rawValue {
            // Start a manual lifecycle continuous profile (v2).
            setProfileConfiguration(lifecycle: .manual, decision: decision, shouldWaitForFullDisplay: shouldWaitForFullDisplay)
            SentryContinuousProfiler.start()
            return
        }

        setProfileConfiguration(lifecycle: .trace, decision: decision, shouldWaitForFullDisplay: shouldWaitForFullDisplay)
        startTraceProfiler(launchConfig, decision: decision)
    }

    private static func launchProfileDecision(for options: Options) -> LaunchProfileDecision? {
        guard let profiling = options.profiling else {
            return nil
        }

        guard profiling.profileAppStarts else {
            SentrySDKLog.debug("Continuous profiling v2 enabled but disabled app start profiling, won't profile launch.")
            return nil
        }

        guard profiling.lifecycle == .trace else {
            let profilesDecision = SentrySampling.sampleProfileSession(profiling.sessionSampleRate)
            guard profilesDecision.decision == .yes else {
                SentrySDKLog.debug("Sampling out continuous v2 profile, won't profile launch.")
                return nil
            }

            SentrySDKLog.debug("Continuous profiling v2 manual lifecycle conditions satisfied, will profile launch.")
            return LaunchProfileDecision(tracesDecision: nil, profilesDecision: profilesDecision)
        }

        guard options.isTracingEnabled else {
            SentrySDKLog.debug("Continuous profiling v2 enabled for trace lifecycle but tracing is disabled, won't profile launch.")
            SentrySDKLog.warning("Tracing must be enabled in order to configure app start profiling with trace lifecycle. See SentryOptions.tracesSampleRate and SentryOptions.tracesSampler.")
            return nil
        }

        let transactionContext = TransactionContext(name: "app.launch", operation: "profile")
        transactionContext.forNextAppLaunch = true
        let tracesDecision = SentrySampling.sampleTrace(SamplingContext(transactionContext: transactionContext), options: options)
        guard tracesDecision.decision == .yes else {
            SentrySDKLog.debug("Sampling out the launch trace for continuous profile v2 trace lifecycle, won't profile launch.")
            return nil
        }

        let profilesDecision = SentrySampling.sampleProfileSession(profiling.sessionSampleRate)
        guard profilesDecision.decision == .yes else {
            SentrySDKLog.debug("Sampling out continuous v2 trace lifecycle profile, won't profile launch.")
            return nil
        }

        SentrySDKLog.debug("Continuous profiling v2 trace lifecycle conditions satisfied, will profile launch.")
        return LaunchProfileDecision(tracesDecision: tracesDecision, profilesDecision: profilesDecision)
    }

    private static func profileSampleDecision(_ launchConfig: [String: NSNumber]) -> SentrySamplerDecision? {
        guard let profilesRand = launchConfig[SentryLaunchProfileConfigKey.profilesSampleRand] else {
            SentrySDKLog.debug("Received a nil configured launch profile sample rand, will not start trace profiler for launch.")
            return nil
        }

        guard let profilesRate = launchConfig[SentryLaunchProfileConfigKey.profilesSampleRate] else {
            SentrySDKLog.debug("Tried to start a profile with no configured sample rate. Will not run profiler.")
            return nil
        }

        return SentrySamplerDecision(decision: .yes, forSampleRate: profilesRate, withSampleRand: profilesRand)
    }

    /// Creates the profile configuration from the values persisted by the previous launch and sets
    /// the in-memory data structure.
    private static func setProfileConfiguration(
        lifecycle: SentryProfileOptions.SentryProfileLifecycle,
        decision: SentrySamplerDecision,
        shouldWaitForFullDisplay: Bool
    ) {
        let profileOptions = SentryProfileOptions()
        profileOptions.lifecycle = lifecycle
        profileOptions.profileAppStarts = true
        profileOptions.sessionSampleRate = decision.sampleRate?.floatValue ?? 0

        sentry_setProfileConfiguration(SentryProfileConfiguration(
            continuousProfilingV2WaitingForFullDisplay: shouldWaitForFullDisplay,
            samplerDecision: decision,
            profileOptions: profileOptions
        ))
    }

    private static func startTraceProfiler(_ launchConfig: [String: NSNumber], decision: SentrySamplerDecision) {
        guard let tracesRate = launchConfig[SentryLaunchProfileConfigKey.tracesSampleRate] else {
            SentrySDKLog.debug("Received a nil configured launch trace sample rate, will not start trace profiler for launch.")
            return
        }

        guard let tracesRand = launchConfig[SentryLaunchProfileConfigKey.tracesSampleRand] else {
            SentrySDKLog.debug("Received a nil configured launch trace sample rand, will not start trace profiler for launch.")
            return
        }

        SentrySDKLog.info("Starting app launch trace profile at \(SentryDefaultCurrentDateProvider.getAbsoluteTime()).")

        // Creating the tracer starts the profiler, which reads this flag, so it must be set before
        // and the lock must not be held meanwhile.
        isTracingAppLaunch = true

        let tracerConfiguration = SentryTracerConfiguration.default
        tracerConfiguration.profilesSamplerDecision = decision

        let transactionContext = TransactionContext(
            name: "launch",
            operation: SentrySpanOperationAppLifecycle,
            sampled: .yes,
            sampleRate: tracesRate,
            sampleRand: tracesRand
        )
        transactionContext.origin = SentryTraceOriginAutoAppStartProfile

        launchTracer = SentryTracer(transactionContext: transactionContext, hub: nil, configuration: tracerConfiguration)
    }
}

#endif // os(iOS) || os(macOS)
