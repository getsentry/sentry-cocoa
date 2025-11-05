#import "SentryOptionsInternal.h"
#import "SentryDsn.h"
#import "SentryHttpStatusCodeRange.h"
#import "SentryInternalDefines.h"
#import "SentryLevelMapper.h"
#import "SentryLogC.h"
#import "SentryMeta.h"
#import "SentryOptionsInternal+Private.h"
#import "SentrySDKInternal.h"
#import "SentryScope.h"
#import "SentrySwift.h"
#import "SentryTracer.h"
#import <objc/runtime.h>

NSString *const kSentryDefaultEnvironment = @"production";

@implementation SentryOptionsInternal {
    id _beforeSendLogDynamic;
#if SENTRY_TARGET_REPLAY_SUPPORTED
    id _sessionReplayDynamic;
#endif
#if TARGET_OS_IOS && SENTRY_HAS_UIKIT
    id _userFeedbackDynamic;
#endif
}

// Provide explicit implementation for SPM builds where the property is excluded from header
// Use id to avoid typedef dependency, Swift extension provides type safety
- (id)beforeSendLogDynamic
{
    return _beforeSendLogDynamic;
}

- (void)setBeforeSendLogDynamic:(id)beforeSendLogDynamic
{
    _beforeSendLogDynamic = beforeSendLogDynamic;
}

#if SENTRY_TARGET_REPLAY_SUPPORTED
- (id)sessionReplayDynamic
{
    return _sessionReplayDynamic;
}

- (void)setSessionReplayDynamic:(id)sessionReplayDynamic
{
    _sessionReplayDynamic = sessionReplayDynamic;
}
#endif

#if TARGET_OS_IOS && SENTRY_HAS_UIKIT
- (id)userFeedbackDynamic
{
    return _userFeedbackDynamic;
}

- (void)setUserFeedbackDynamic:(id)userFeedbackDynamic
{
    _userFeedbackDynamic = userFeedbackDynamic;
}
#endif

+ (nullable SentryOptions *)initWithDict:(NSDictionary<NSString *, id> *)options
                        didFailWithError:(NSError *_Nullable *_Nullable)error
{
    return [[SentryOptions alloc] init];
}

- (instancetype)init
{
    if (self = [super init]) {
        self.enabled = YES;
        self.shutdownTimeInterval = 2.0;
        self.enableCrashHandler = YES;
#if TARGET_OS_OSX
        self.enableUncaughtNSExceptionReporting = NO;
#endif // TARGET_OS_OSX
#if !TARGET_OS_WATCH
        self.enableSigtermReporting = NO;
#endif // !TARGET_OS_WATCH
        self.diagnosticLevel = kSentryLevelDebug;
        self.debug = NO;
        self.maxBreadcrumbs = defaultMaxBreadcrumbs;
        self.maxCacheItems = 30;
        self.sampleRate = SENTRY_DEFAULT_SAMPLE_RATE;
        self.enableAutoSessionTracking = YES;
        self.enableGraphQLOperationTracking = NO;
        self.enableWatchdogTerminationTracking = YES;
        self.sessionTrackingIntervalMillis = [@30000 unsignedIntValue];
        self.attachStacktrace = YES;
        // Maximum attachment size is 100 MiB, matches Relay's limit:
        // https://develop.sentry.dev/sdk/data-model/envelopes/#size-limits
        self.maxAttachmentSize = 100 * 1024 * 1024;
        self.sendDefaultPii = NO;
        self.enableAutoPerformanceTracing = YES;
        self.enablePersistingTracesWhenCrashing = NO;
        self.enableCaptureFailedRequests = YES;
        self.environment = kSentryDefaultEnvironment;
        self.enableTimeToFullDisplayTracing = NO;

        self.initialScope = ^SentryScope *(SentryScope *scope) { return scope; };
        __swiftExperimentalOptions = [[SentryExperimentalOptions alloc] init];
#if SENTRY_HAS_UIKIT
        self.enableUIViewControllerTracing = YES;
        self.attachScreenshot = NO;
        self.screenshot = [[SentryViewScreenshotOptions alloc] init];
        self.attachViewHierarchy = NO;
        self.reportAccessibilityIdentifier = YES;
        self.enableUserInteractionTracing = YES;
        self.idleTimeout = SentryTracerDefaultTimeout;
        self.enablePreWarmedAppStartTracing = YES;
        self.enableReportNonFullyBlockingAppHangs = YES;
#endif // SENTRY_HAS_UIKIT

#if SENTRY_TARGET_REPLAY_SUPPORTED
        _sessionReplayDynamic = [[SentryReplayOptions alloc] init];
#endif

        self.enableAppHangTracking = YES;
        self.appHangTimeoutInterval = 2.0;
        self.enableAutoBreadcrumbTracking = YES;
        self.enablePropagateTraceparent = NO;
        self.enableNetworkTracking = YES;
        self.enableFileIOTracing = YES;
        self.enableFileManagerSwizzling = NO;
        self.enableDataSwizzling = YES;
        self.enableNetworkBreadcrumbs = YES;
        self.enableLogs = NO;
        self.tracesSampleRate = nil;
        self.enableCoreDataTracing = YES;
        _enableSwizzling = YES;
        self.swizzleClassNameExcludes = [NSSet new];
        self.sendClientReports = YES;
        self.swiftAsyncStacktraces = NO;
        self.enableSpotlight = NO;
        self.spotlightUrl = @"http://localhost:8969/stream";

#if TARGET_OS_OSX
        NSString *dsn = [[[NSProcessInfo processInfo] environment] objectForKey:@"SENTRY_DSN"];
        if (dsn.length > 0) {
            self.dsn = dsn;
        }
#endif // TARGET_OS_OSX

        // Use the name of the bundle's executable file as inAppInclude, so SentryInAppLogic
        // marks frames coming from there as inApp. With this approach, the SDK marks public
        // frameworks such as UIKitCore, CoreFoundation, GraphicsServices, and so forth, as not
        // inApp. For private frameworks, such as Sentry, dynamic and static frameworks differ.
        // Suppose you use dynamic frameworks inside your app. In that case, the SDK marks these as
        // not inApp as these frameworks are located in the application bundle, but their location
        // is different from the main executable.  In case you have a private framework that should
        // be inApp you can add it to inAppInclude. When using static frameworks, the frameworks end
        // up in the main executable. Therefore, the SDK currently can't detect if a frame of the
        // main executable originates from the application or a private framework and marks all of
        // them as inApp. To fix this, the user can use stack trace rules on Sentry.
        NSDictionary *infoDict = [[NSBundle mainBundle] infoDictionary];
        NSString *bundleExecutable = infoDict[@"CFBundleExecutable"];
        if (bundleExecutable == nil) {
            _inAppIncludes = [NSArray new];
        } else {
            _inAppIncludes = @[ bundleExecutable ];
        }

        _inAppExcludes = [NSArray new];

        // Set default release name
        if (infoDict != nil) {
            self.releaseName =
                [NSString stringWithFormat:@"%@@%@+%@", infoDict[@"CFBundleIdentifier"],
                    infoDict[@"CFBundleShortVersionString"], infoDict[@"CFBundleVersion"]];
        }

        NSRegularExpression *everythingAllowedRegex =
            [NSRegularExpression regularExpressionWithPattern:@".*"
                                                      options:NSRegularExpressionCaseInsensitive
                                                        error:NULL];
        self.tracePropagationTargets = @[ everythingAllowedRegex ];
        self.failedRequestTargets = @[ everythingAllowedRegex ];

        // defaults to 500 to 599
        SentryHttpStatusCodeRange *defaultHttpStatusCodeRange =
            [[SentryHttpStatusCodeRange alloc] initWithMin:500 max:599];
        self.failedRequestStatusCodes = @[ defaultHttpStatusCodeRange ];

        self.cacheDirectoryPath
            = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES)
                  .firstObject
            ?: @"";

#if SENTRY_HAS_METRIC_KIT
        self.enableMetricKit = NO;
        self.enableMetricKitRawPayload = NO;
#endif // SENTRY_HAS_METRIC_KIT
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

- (void)setSampleRate:(NSNumber *)sampleRate
{
    if (sampleRate == nil) {
        _sampleRate = nil;
    } else if (sentry_isValidSampleRate(sampleRate)) {
        _sampleRate = sampleRate;
    } else {
        _sampleRate = SENTRY_DEFAULT_SAMPLE_RATE;
    }
}

- (void)setTracesSampleRate:(NSNumber *)tracesSampleRate
{
    if (tracesSampleRate == nil) {
        _tracesSampleRate = nil;
    } else if (sentry_isValidSampleRate(tracesSampleRate)) {
        _tracesSampleRate = tracesSampleRate;
    } else {
        _tracesSampleRate = SENTRY_DEFAULT_TRACES_SAMPLE_RATE;
    }
}

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
