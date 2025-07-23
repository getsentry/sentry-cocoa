#import "SentryANRTrackingIntegration.h"
#import "SentryAutoBreadcrumbTrackingIntegration.h"
#import "SentryAutoSessionTrackingIntegration.h"
#import "SentryCoreDataTrackingIntegration.h"
#import "SentryCrashIntegration.h"
#import "SentryDsn.h"
#import "SentryFileIOTrackingIntegration.h"
#import "SentryHttpStatusCodeRange.h"
#import "SentryInternalDefines.h"
#import "SentryLevelMapper.h"
#import "SentryLogC.h"
#import "SentryMeta.h"
#import "SentryNetworkTrackingIntegration.h"
#import "SentryOptions+Private.h"
#import "SentrySDKInternal.h"
#import "SentryScope.h"
#import "SentrySessionReplayIntegration.h"
#import "SentrySwift.h"
#import "SentrySwiftAsyncIntegration.h"
#import "SentryTracer.h"
#import <objc/runtime.h>

#if SENTRY_HAS_UIKIT
#    import "SentryAppStartTrackingIntegration.h"
#    import "SentryFramesTrackingIntegration.h"
#    import "SentryPerformanceTrackingIntegration.h"
#    import "SentryScreenshotIntegration.h"
#    import "SentryUIEventTrackingIntegration.h"
#    import "SentryUserFeedbackIntegration.h"
#    import "SentryViewHierarchyIntegration.h"
#    import "SentryWatchdogTerminationTrackingIntegration.h"
#endif // SENTRY_HAS_UIKIT

#if SENTRY_HAS_METRIC_KIT
#    import "SentryMetricKitIntegration.h"
#endif // SENTRY_HAS_METRIC_KIT
NSString *const kSentryDefaultEnvironment = @"production";

@implementation SentryOptionsInternal

+ (NSArray<NSString *> *)defaultIntegrations
{
    NSArray<Class> *defaultIntegrationClasses = [self defaultIntegrationClasses];
    NSMutableArray<NSString *> *defaultIntegrationNames =
        [[NSMutableArray alloc] initWithCapacity:defaultIntegrationClasses.count];

    for (Class class in defaultIntegrationClasses) {
        [defaultIntegrationNames addObject:NSStringFromClass(class)];
    }

    return defaultIntegrationNames;
}

+ (NSArray<Class> *)defaultIntegrationClasses
{
    // The order of integrations here is important.
    // SentryCrashIntegration needs to be initialized before SentryAutoSessionTrackingIntegration.
    // And SentrySessionReplayIntegration before SentryCrashIntegration.
    NSMutableArray<Class> *defaultIntegrations = [NSMutableArray<Class> arrayWithObjects:
#if SENTRY_TARGET_REPLAY_SUPPORTED
            [SentrySessionReplayIntegration class],
#endif // SENTRY_TARGET_REPLAY_SUPPORTED
        [SentryCrashIntegration class],
#if SENTRY_HAS_UIKIT
        [SentryAppStartTrackingIntegration class], [SentryFramesTrackingIntegration class],
        [SentryPerformanceTrackingIntegration class], [SentryUIEventTrackingIntegration class],
        [SentryViewHierarchyIntegration class],
        [SentryWatchdogTerminationTrackingIntegration class],
#endif // SENTRY_HAS_UIKIT
#if SENTRY_TARGET_REPLAY_SUPPORTED
        [SentryScreenshotIntegration class],
#endif // SENTRY_TARGET_REPLAY_SUPPORTED
        [SentryANRTrackingIntegration class], [SentryAutoBreadcrumbTrackingIntegration class],
        [SentryAutoSessionTrackingIntegration class], [SentryCoreDataTrackingIntegration class],
        [SentryFileIOTrackingIntegration class], [SentryNetworkTrackingIntegration class],
        [SentrySwiftAsyncIntegration class], nil];

#if TARGET_OS_IOS && SENTRY_HAS_UIKIT
    if (@available(iOS 13.0, *)) {
        [defaultIntegrations addObject:[SentryUserFeedbackIntegration class]];
    }
#endif // TARGET_OS_IOS && SENTRY_HAS_UIKIT

#if SENTRY_HAS_METRIC_KIT
    if (@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, *)) {
        [defaultIntegrations addObject:[SentryMetricKitIntegration class]];
    }
#endif // SENTRY_HAS_METRIC_KIT

    return defaultIntegrations;
}

/** Only exposed via `SentryOptions+HybridSDKs.h`. */
- (_Nullable instancetype)initWithDict:(NSDictionary<NSString *, id> *)options
                      didFailWithError:(NSError *_Nullable *_Nullable)error
{
    if (self = [self init]) {
        if (![self validateOptions:options didFailWithError:error]) {
            if (error != nil) {
                SENTRY_LOG_ERROR(@"Failed to initialize SentryOptions: %@", *error);
            } else {
                SENTRY_LOG_ERROR(@"Failed to initialize SentryOptions");
            }
            return nil;
        }
    }
    return self;
}

- (void)setTracePropagationTargets:(NSArray *)tracePropagationTargets
{
    for (id targetCheck in tracePropagationTargets) {
        if (![targetCheck isKindOfClass:[NSRegularExpression class]]
            && ![targetCheck isKindOfClass:[NSString class]]) {
            SENTRY_LOG_WARN(@"Only instances of NSString and NSRegularExpression are supported "
                            @"inside tracePropagationTargets.");
        }
    }

    _tracePropagationTargets = tracePropagationTargets;
}

- (void)setFailedRequestTargets:(NSArray *)failedRequestTargets
{
    for (id targetCheck in failedRequestTargets) {
        if (![targetCheck isKindOfClass:[NSRegularExpression class]]
            && ![targetCheck isKindOfClass:[NSString class]]) {
            SENTRY_LOG_WARN(@"Only instances of NSString and NSRegularExpression are supported "
                            @"inside failedRequestTargets.");
        }
    }

    _failedRequestTargets = failedRequestTargets;
}

- (void)setIntegrations:(NSArray<NSString *> *)integrations
{
    SENTRY_LOG_WARN(
        @"Setting `SentryOptions.integrations` is deprecated. Integrations should be enabled or "
        @"disabled using their respective `SentryOptions.enable*` property.");
    _integrations = integrations.mutableCopy;
}

- (void)setDsn:(NSString *)dsn
{
    NSError *error = nil;
    self.parsedDsn = [[SentryDsn alloc] initWithString:dsn didFailWithError:&error];

    if (error == nil) {
        _dsn = dsn;
    } else {
        SENTRY_LOG_ERROR(@"Could not parse the DSN: %@.", error);
    }
}

/**
 * Populates all @c SentryOptions values from @c options dict using fallbacks/defaults if needed.
 */
- (BOOL)validateOptions:(NSDictionary<NSString *, id> *)options
                options:(SentryOptions *)sentryOptions
       didFailWithError:(NSError *_Nullable *_Nullable)error
{
    NSPredicate *isNSString = [NSPredicate predicateWithBlock:^BOOL(
        id object, NSDictionary *bindings) { return [object isKindOfClass:[NSString class]]; }];

    [sentryOptions setBool:options[@"debug"] block:^(BOOL value) { self->_debug = value; }];

    if ([options[@"diagnosticLevel"] isKindOfClass:[NSString class]]) {
        for (SentryLevel level = 0; level <= kSentryLevelFatal; level++) {
            if ([nameForSentryLevel(level) isEqualToString:options[@"diagnosticLevel"]]) {
                sentryOptions.diagnosticLevel = level;
                break;
            }
        }
    }

    if (options[@"dsn"] != [NSNull null]) {
        NSString *dsn = @"";
        if (nil != options[@"dsn"] && [options[@"dsn"] isKindOfClass:[NSString class]]) {
            dsn = options[@"dsn"];
        }

        sentryOptions.parsedDsn = [[SentryDsn alloc] initWithString:dsn didFailWithError:error];
        if (sentryOptions.parsedDsn == nil) {
            return NO;
        }
    }

    if ([options[@"release"] isKindOfClass:[NSString class]]) {
        sentryOptions.releaseName = options[@"release"];
    }

    if ([options[@"environment"] isKindOfClass:[NSString class]]) {
        sentryOptions.environment = options[@"environment"];
    }

    if ([options[@"dist"] isKindOfClass:[NSString class]]) {
        sentryOptions.dist = options[@"dist"];
    }

    [sentryOptions setBool:options[@"enabled"] block:^(BOOL value) { self->_enabled = value; }];

    if ([options[@"shutdownTimeInterval"] isKindOfClass:[NSNumber class]]) {
        sentryOptions.shutdownTimeInterval = [options[@"shutdownTimeInterval"] doubleValue];
    }

    [sentryOptions setBool:options[@"enableCrashHandler"]
                     block:^(BOOL value) { self->_enableCrashHandler = value; }];

#if TARGET_OS_OSX
    [sentryOptions setBool:options[@"enableUncaughtNSExceptionReporting"]
                     block:^(BOOL value) { self->_enableUncaughtNSExceptionReporting = value; }];
#endif // TARGET_OS_OSX

#if !TARGET_OS_WATCH
    [sentryOptions setBool:options[@"enableSigtermReporting"]
                     block:^(BOOL value) { self->_enableSigtermReporting = value; }];
#endif // !TARGET_OS_WATCH

    if ([options[@"maxBreadcrumbs"] isKindOfClass:[NSNumber class]]) {
        sentryOptions.maxBreadcrumbs = [options[@"maxBreadcrumbs"] unsignedIntValue];
    }

    [sentryOptions setBool:options[@"enableNetworkBreadcrumbs"]
                     block:^(BOOL value) { self->_enableNetworkBreadcrumbs = value; }];

    if ([options[@"maxCacheItems"] isKindOfClass:[NSNumber class]]) {
        sentryOptions.maxCacheItems = [options[@"maxCacheItems"] unsignedIntValue];
    }

    if ([options[@"cacheDirectoryPath"] isKindOfClass:[NSString class]]) {
        sentryOptions.cacheDirectoryPath = options[@"cacheDirectoryPath"];
    }

    if ([SentryOptionsInternal isBlock:options[@"beforeSend"]]) {
        sentryOptions.beforeSend = options[@"beforeSend"];
    }

    if ([SentryOptionsInternal isBlock:options[@"beforeSendSpan"]]) {
        sentryOptions.beforeSendSpan = options[@"beforeSendSpan"];
    }

    if ([SentryOptionsInternal isBlock:options[@"beforeBreadcrumb"]]) {
        sentryOptions.beforeBreadcrumb = options[@"beforeBreadcrumb"];
    }

    if ([SentryOptionsInternal isBlock:options[@"beforeCaptureScreenshot"]]) {
        sentryOptions.beforeCaptureScreenshot = options[@"beforeCaptureScreenshot"];
    }

    if ([SentryOptionsInternal isBlock:options[@"beforeCaptureViewHierarchy"]]) {
        sentryOptions.beforeCaptureViewHierarchy = options[@"beforeCaptureViewHierarchy"];
    }

    if ([SentryOptionsInternal isBlock:options[@"onCrashedLastRun"]]) {
        sentryOptions.onCrashedLastRun = options[@"onCrashedLastRun"];
    }

    if ([options[@"integrations"] isKindOfClass:[NSArray class]]) {
        sentryOptions.integrations =
            [[options[@"integrations"] filteredArrayUsingPredicate:isNSString] mutableCopy];
    }

    if ([options[@"sampleRate"] isKindOfClass:[NSNumber class]]) {
        sentryOptions.sampleRate = options[@"sampleRate"];
    }

    [sentryOptions setBool:options[@"enableAutoSessionTracking"]
                     block:^(BOOL value) { self->_enableAutoSessionTracking = value; }];

    [sentryOptions setBool:options[@"enableGraphQLOperationTracking"]
                     block:^(BOOL value) { self->_enableGraphQLOperationTracking = value; }];

    [sentryOptions setBool:options[@"enableWatchdogTerminationTracking"]
                     block:^(BOOL value) { self->_enableWatchdogTerminationTracking = value; }];

    [sentryOptions setBool:options[@"swiftAsyncStacktraces"]
                     block:^(BOOL value) { self->_swiftAsyncStacktraces = value; }];

    if ([options[@"sessionTrackingIntervalMillis"] isKindOfClass:[NSNumber class]]) {
        sentryOptions.sessionTrackingIntervalMillis =
            [options[@"sessionTrackingIntervalMillis"] unsignedIntValue];
    }

    [sentryOptions setBool:options[@"attachStacktrace"]
                     block:^(BOOL value) { self->_attachStacktrace = value; }];

    if ([options[@"maxAttachmentSize"] isKindOfClass:[NSNumber class]]) {
        sentryOptions.maxAttachmentSize = [options[@"maxAttachmentSize"] unsignedIntValue];
    }

    [sentryOptions setBool:options[@"sendDefaultPii"]
                     block:^(BOOL value) { self->_sendDefaultPii = value; }];

    [sentryOptions setBool:options[@"enableAutoPerformanceTracing"]
                     block:^(BOOL value) { self->_enableAutoPerformanceTracing = value; }];

    [sentryOptions setBool:options[@"enablePerformanceV2"]
                     block:^(BOOL value) { self->_enablePerformanceV2 = value; }];

    [sentryOptions setBool:options[@"enablePersistingTracesWhenCrashing"]
                     block:^(BOOL value) { self->_enablePersistingTracesWhenCrashing = value; }];

    [sentryOptions setBool:options[@"enableCaptureFailedRequests"]
                     block:^(BOOL value) { self->_enableCaptureFailedRequests = value; }];

    [sentryOptions setBool:options[@"enableTimeToFullDisplayTracing"]
                     block:^(BOOL value) { self->_enableTimeToFullDisplayTracing = value; }];

    if ([SentryOptionsInternal isBlock:options[@"initialScope"]]) {
        sentryOptions.initialScope = options[@"initialScope"];
    }
#if SENTRY_HAS_UIKIT
    [sentryOptions setBool:options[@"enableUIViewControllerTracing"]
                     block:^(BOOL value) { self->_enableUIViewControllerTracing = value; }];

    [sentryOptions setBool:options[@"attachScreenshot"]
                     block:^(BOOL value) { self->_attachScreenshot = value; }];

    [sentryOptions setBool:options[@"attachViewHierarchy"]
                     block:^(BOOL value) { self->_attachViewHierarchy = value; }];

    [sentryOptions setBool:options[@"reportAccessibilityIdentifier"]
                     block:^(BOOL value) { self->_reportAccessibilityIdentifier = value; }];

    [sentryOptions setBool:options[@"enableUserInteractionTracing"]
                     block:^(BOOL value) { self->_enableUserInteractionTracing = value; }];

    if ([options[@"idleTimeout"] isKindOfClass:[NSNumber class]]) {
        sentryOptions.idleTimeout = [options[@"idleTimeout"] doubleValue];
    }

    [sentryOptions setBool:options[@"enablePreWarmedAppStartTracing"]
                     block:^(BOOL value) { self->_enablePreWarmedAppStartTracing = value; }];

#    if !SDK_V9
    [sentryOptions setBool:options[@"enableAppHangTrackingV2"]
                     block:^(BOOL value) { self->_enableAppHangTrackingV2 = value; }];
#    endif // !SDK_V9

    [sentryOptions setBool:options[@"enableReportNonFullyBlockingAppHangs"]
                     block:^(BOOL value) { self->_enableReportNonFullyBlockingAppHangs = value; }];

#endif // SENTRY_HAS_UIKIT

#if SENTRY_TARGET_REPLAY_SUPPORTED
    if ([options[@"sessionReplay"] isKindOfClass:NSDictionary.class]) {
        sentryOptions.sessionReplay =
            [[SentryReplayOptions alloc] initWithDictionary:options[@"sessionReplay"]];
    }
#endif // SENTRY_TARGET_REPLAY_SUPPORTED

    [sentryOptions setBool:options[@"enableAppHangTracking"]
                     block:^(BOOL value) { self->_enableAppHangTracking = value; }];

    if ([options[@"appHangTimeoutInterval"] isKindOfClass:[NSNumber class]]) {
        sentryOptions.appHangTimeoutInterval = [options[@"appHangTimeoutInterval"] doubleValue];
    }

    [sentryOptions setBool:options[@"enableNetworkTracking"]
                     block:^(BOOL value) { self->_enableNetworkTracking = value; }];

    [sentryOptions setBool:options[@"enableFileIOTracing"]
                     block:^(BOOL value) { self->_enableFileIOTracing = value; }];

    if ([options[@"tracesSampleRate"] isKindOfClass:[NSNumber class]]) {
        sentryOptions.tracesSampleRate = options[@"tracesSampleRate"];
    }

    if ([SentryOptionsInternal isBlock:options[@"tracesSampler"]]) {
        sentryOptions.tracesSampler = options[@"tracesSampler"];
    }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    if ([options[@"enableTracing"] isKindOfClass:NSNumber.self]) {
        sentryOptions.enableTracing = [options[@"enableTracing"] boolValue];
    }
#pragma clang diagnostic pop

    if ([options[@"inAppIncludes"] isKindOfClass:[NSArray class]]) {
        NSArray<NSString *> *inAppIncludes =
            [options[@"inAppIncludes"] filteredArrayUsingPredicate:isNSString];
        _inAppIncludes = [_inAppIncludes arrayByAddingObjectsFromArray:inAppIncludes];
    }

    if ([options[@"inAppExcludes"] isKindOfClass:[NSArray class]]) {
        _inAppExcludes = [options[@"inAppExcludes"] filteredArrayUsingPredicate:isNSString];
    }

    if ([options[@"urlSession"] isKindOfClass:[NSURLSession class]]) {
        sentryOptions.urlSession = options[@"urlSession"];
    }

    if ([options[@"urlSessionDelegate"] conformsToProtocol:@protocol(NSURLSessionDelegate)]) {
        sentryOptions.urlSessionDelegate = options[@"urlSessionDelegate"];
    }

    [sentryOptions setBool:options[@"enableSwizzling"]
                     block:^(BOOL value) { self->_enableSwizzling = value; }];

    if ([options[@"swizzleClassNameExcludes"] isKindOfClass:[NSSet class]]) {
        _swizzleClassNameExcludes =
            [options[@"swizzleClassNameExcludes"] filteredSetUsingPredicate:isNSString];
    }

    [sentryOptions setBool:options[@"enableCoreDataTracing"]
                     block:^(BOOL value) { self->_enableCoreDataTracing = value; }];

#if SENTRY_TARGET_PROFILING_SUPPORTED
#    if !SDK_V9
    if ([options[@"profilesSampleRate"] isKindOfClass:[NSNumber class]]) {
#        pragma clang diagnostic push
#        pragma clang diagnostic ignored "-Wdeprecated-declarations"
        sentryOptions.profilesSampleRate = options[@"profilesSampleRate"];
#        pragma clang diagnostic pop
    }

#        pragma clang diagnostic push
#        pragma clang diagnostic ignored "-Wdeprecated-declarations"
    if ([SentryOptionsInternal isBlock:options[@"profilesSampler"]]) {
        sentryOptions.profilesSampler = options[@"profilesSampler"];
    }
#        pragma clang diagnostic pop

    [sentryOptions setBool:options[@"enableProfiling"]
                     block:^(BOOL value) { self->_enableProfiling = value; }];

    [sentryOptions setBool:options[NSStringFromSelector(@selector(enableAppLaunchProfiling))]
                     block:^(BOOL value) { self->_enableAppLaunchProfiling = value; }];
#    endif // !SDK_V9
#endif // SENTRY_TARGET_PROFILING_SUPPORTED

    [sentryOptions setBool:options[@"sendClientReports"]
                     block:^(BOOL value) { self->_sendClientReports = value; }];

    [sentryOptions setBool:options[@"enableAutoBreadcrumbTracking"]
                     block:^(BOOL value) { self->_enableAutoBreadcrumbTracking = value; }];

    if ([options[@"tracePropagationTargets"] isKindOfClass:[NSArray class]]) {
        sentryOptions.tracePropagationTargets = options[@"tracePropagationTargets"];
    }

    if ([options[@"failedRequestStatusCodes"] isKindOfClass:[NSArray class]]) {
        sentryOptions.failedRequestStatusCodes = options[@"failedRequestStatusCodes"];
    }

    if ([options[@"failedRequestTargets"] isKindOfClass:[NSArray class]]) {
        sentryOptions.failedRequestTargets = options[@"failedRequestTargets"];
    }

#if SENTRY_HAS_METRIC_KIT
    if (@available(iOS 14.0, macOS 12.0, macCatalyst 14.0, *)) {
        [sentryOptions setBool:options[@"enableMetricKit"]
                         block:^(BOOL value) { self->_enableMetricKit = value; }];
        [sentryOptions setBool:options[@"enableMetricKitRawPayload"]
                         block:^(BOOL value) { self->_enableMetricKitRawPayload = value; }];
    }
#endif // SENTRY_HAS_METRIC_KIT

    [sentryOptions setBool:options[@"enableSpotlight"]
                     block:^(BOOL value) { self->_enableSpotlight = value; }];

    if ([options[@"spotlightUrl"] isKindOfClass:[NSString class]]) {
        sentryOptions.spotlightUrl = options[@"spotlightUrl"];
    }

    if ([options[@"experimental"] isKindOfClass:NSDictionary.class]) {
        [sentryOptions.experimental validateOptions:options[@"experimental"]];
    }

    return YES;
}

#if SENTRY_TARGET_PROFILING_SUPPORTED
#    if !SDK_V9
- (void)setProfilesSampleRate:(NSNumber *)profilesSampleRate
{
    if (profilesSampleRate == nil) {
        _profilesSampleRate = nil;
    } else if (sentry_isValidSampleRate(profilesSampleRate)) {
        _profilesSampleRate = profilesSampleRate;
    } else {
        _profilesSampleRate = SENTRY_DEFAULT_PROFILES_SAMPLE_RATE;
    }
}

- (BOOL)isProfilingEnabled
{
    return (_profilesSampleRate != nil && [_profilesSampleRate doubleValue] > 0)
        || _profilesSampler != nil || _enableProfiling;
}

- (BOOL)isContinuousProfilingEnabled
{
#        pragma clang diagnostic push
#        pragma clang diagnostic ignored "-Wdeprecated-declarations"
    // this looks a little weird with the `!self.enableProfiling` but that actually is the
    // deprecated way to say "enable trace-based profiling", which necessarily disables continuous
    // profiling as they are mutually exclusive modes
    return _profilesSampleRate == nil && _profilesSampler == nil && !self.enableProfiling;
#        pragma clang diagnostic pop
}

#    endif // !SDK_V9

- (BOOL)isContinuousProfilingV2Enabled
{
#    if SDK_V9
    return _profiling != nil;
#    else
    return [self isContinuousProfilingEnabled] && _profiling != nil;
#    endif // SDK_V9
}

- (BOOL)isProfilingCorrelatedToTraces
{
#    if SDK_V9
    return _profiling != nil && _profiling.lifecycle == SentryProfileLifecycleTrace;
#    else
    return ![self isContinuousProfilingEnabled]
        || (_profiling != nil && _profiling.lifecycle == SentryProfileLifecycleTrace);
#    endif // SDK_V9
}

#    if !SDK_V9
- (void)setEnableProfiling_DEPRECATED_TEST_ONLY:(BOOL)enableProfiling_DEPRECATED_TEST_ONLY
{
#        pragma clang diagnostic push
#        pragma clang diagnostic ignored "-Wdeprecated-declarations"
    self.enableProfiling = enableProfiling_DEPRECATED_TEST_ONLY;
#        pragma clang diagnostic pop
}

- (BOOL)enableProfiling_DEPRECATED_TEST_ONLY
{
#        pragma clang diagnostic push
#        pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return self.enableProfiling;
#        pragma clang diagnostic pop
}
#    endif // !SDK_V9
#endif // SENTRY_TARGET_PROFILING_SUPPORTED

/**
 * Checks if the passed in block is actually of type block. We can't check if the block matches a
 * specific block without some complex objc runtime method calls and therefore we only check if it's
 * a block or not. Assigning a wrong block to the @c SentryOptions blocks still could lead to
 * crashes at runtime, but when someone uses the @c initWithDict they should better know what they
 * are doing.
 * @see Taken from https://gist.github.com/steipete/6ee378bd7d87f276f6e0
 */
+ (BOOL)isBlock:(nullable id)block
{
    static Class blockClass;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        blockClass = [^{ } class];
        while ([blockClass superclass] != NSObject.class) {
            blockClass = [blockClass superclass];
        }
    });

    return [block isKindOfClass:blockClass];
}

#if SENTRY_UIKIT_AVAILABLE

- (void)setEnableUIViewControllerTracing:(BOOL)enableUIViewControllerTracing
{
#    if SENTRY_HAS_UIKIT
    _enableUIViewControllerTracing = enableUIViewControllerTracing;
#    else
    SENTRY_GRACEFUL_FATAL(
        @"enableUIViewControllerTracing only works with UIKit enabled. Ensure you're "
        @"using the right configuration of Sentry that links UIKit.");
#    endif // SENTRY_HAS_UIKIT
}

- (void)setAttachScreenshot:(BOOL)attachScreenshot
{
#    if SENTRY_HAS_UIKIT
    _attachScreenshot = attachScreenshot;
#    else
    SENTRY_GRACEFUL_FATAL(
        @"attachScreenshot only works with UIKit enabled. Ensure you're using the "
        @"right configuration of Sentry that links UIKit.");
#    endif // SENTRY_HAS_UIKIT
}

- (void)setAttachViewHierarchy:(BOOL)attachViewHierarchy
{
#    if SENTRY_HAS_UIKIT
    _attachViewHierarchy = attachViewHierarchy;
#    else
    SENTRY_GRACEFUL_FATAL(
        @"attachViewHierarchy only works with UIKit enabled. Ensure you're using the "
        @"right configuration of Sentry that links UIKit.");
#    endif // SENTRY_HAS_UIKIT
}

#    if SENTRY_TARGET_REPLAY_SUPPORTED

- (BOOL)enableViewRendererV2
{
    return self.sessionReplay.enableViewRendererV2;
}

- (BOOL)enableFastViewRendering
{
    return self.sessionReplay.enableFastViewRendering;
}

#    endif // SENTRY_TARGET_REPLAY_SUPPORTED

- (void)setEnableUserInteractionTracing:(BOOL)enableUserInteractionTracing
{
#    if SENTRY_HAS_UIKIT
    _enableUserInteractionTracing = enableUserInteractionTracing;
#    else
    SENTRY_GRACEFUL_FATAL(
        @"enableUserInteractionTracing only works with UIKit enabled. Ensure you're "
        @"using the right configuration of Sentry that links UIKit.");
#    endif // SENTRY_HAS_UIKIT
}

- (void)setIdleTimeout:(NSTimeInterval)idleTimeout
{
#    if SENTRY_HAS_UIKIT
    _idleTimeout = idleTimeout;
#    else
    SENTRY_GRACEFUL_FATAL(
        @"idleTimeout only works with UIKit enabled. Ensure you're using the right "
        @"configuration of Sentry that links UIKit.");
#    endif // SENTRY_HAS_UIKIT
}

- (void)setEnablePreWarmedAppStartTracing:(BOOL)enablePreWarmedAppStartTracing
{
#    if SENTRY_HAS_UIKIT
    _enablePreWarmedAppStartTracing = enablePreWarmedAppStartTracing;
#    else
    SENTRY_GRACEFUL_FATAL(
        @"enablePreWarmedAppStartTracing only works with UIKit enabled. Ensure you're "
        @"using the right configuration of Sentry that links UIKit.");
#    endif // SENTRY_HAS_UIKIT
}

#endif // SENTRY_UIKIT_AVAILABLE

- (void)setEnableSpotlight:(BOOL)value
{
    _enableSpotlight = value;
#if defined(RELEASE)
    if (value) {
        SENTRY_LOG_WARN(@"Enabling Spotlight for a release build. We recommend running Spotlight "
                        @"only for local development.");
    }
#endif // defined(RELEASE)
}

#if SENTRY_HAS_UIKIT
- (BOOL)isAppHangTrackingV2Disabled
{
#    if SDK_V9
    BOOL isV2Enabled = self.enableAppHangTracking;
#    else
    BOOL isV2Enabled = self.enableAppHangTrackingV2;
#    endif // SDK_V9
    return !isV2Enabled || self.appHangTimeoutInterval <= 0;
}
#endif // SENTRY_HAS_UIKIT

#if TARGET_OS_IOS && SENTRY_HAS_UIKIT
- (void)setConfigureUserFeedback:(SentryUserFeedbackConfigurationBlock)configureUserFeedback
{
    self.userFeedbackConfiguration = [[SentryUserFeedbackConfiguration alloc] init];
    configureUserFeedback(self.userFeedbackConfiguration);
}
#endif // TARGET_OS_IOS && SENTRY_HAS_UIKIT

#if defined(DEBUG) || defined(SENTRY_TEST) || defined(SENTRY_TEST_CI)
- (NSString *)debugDescription
{
    NSMutableString *propertiesDescription = [NSMutableString string];
    @autoreleasepool {
        unsigned int outCount, i;
        objc_property_t *properties = class_copyPropertyList([self class], &outCount);
        for (i = 0; i < outCount; i++) {
            objc_property_t property = properties[i];
            const char *propName = property_getName(property);
            if (propName) {
                NSString *propertyName = [NSString stringWithUTF8String:propName];
                NSString *propertyValue = [[self valueForKey:propertyName] description];
                [propertiesDescription appendFormat:@"  %@: %@\n", propertyName, propertyValue];
            } else {
                SENTRY_LOG_DEBUG(@"Failed to get a property name.");
            }
        }
        free(properties);
    }
    return [NSString stringWithFormat:@"<%@: {\n%@\n}>", self, propertiesDescription];
}
#endif // defined(DEBUG) || defined(SENTRY_TEST) || defined(SENTRY_TEST_CI)

@end
