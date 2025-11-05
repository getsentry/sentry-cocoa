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
        self.enableAutoSessionTracking = YES;
        self.enableGraphQLOperationTracking = NO;
        self.enableWatchdogTerminationTracking = YES;
        self.attachStacktrace = YES;
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

#if SENTRY_HAS_METRIC_KIT
        self.enableMetricKit = NO;
        self.enableMetricKitRawPayload = NO;
#endif // SENTRY_HAS_METRIC_KIT
    }
    return self;
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
