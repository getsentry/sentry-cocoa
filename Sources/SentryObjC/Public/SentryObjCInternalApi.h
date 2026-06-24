#import <Foundation/Foundation.h>
#if !__has_include(<SentryObjC/SentryObjCDefines.h>)
#    import "SentryObjCDefines.h"
#else
#    import <SentryObjC/SentryObjCDefines.h>
#endif

@class SentryObjCId;
@class SentryObjCSpanId;
@class SentryObjCOptions;
@class SentryObjCInternalSdkApi;
@class SentryObjCInternalDebugApi;
@class SentryObjCInternalBreadcrumbApi;
@class SentryObjCInternalUserApi;
@class SentryObjCInternalEnvelopeApi;
@class SentryObjCInternalSwizzleApi;
@class SentryObjCInternalAppStartApi;
#if SENTRY_OBJC_HAS_UIKIT
@class SentryObjCInternalPerformanceApi;
#    if !TARGET_OS_VISION
@class SentryObjCInternalScreenshotApi;
@class SentryObjCInternalViewHierarchyApi;
@class SentryObjCInternalScreenApi;
#    endif
#endif
#if SENTRY_OBJC_REPLAY_SUPPORTED
@class SentryObjCInternalReplayApi;
#endif
#if SENTRY_OBJC_PROFILING_SUPPORTED
@class SentryObjCInternalProfilingApi;
#endif

NS_ASSUME_NONNULL_BEGIN

/// APIs intended for Sentry hybrid SDKs (React Native, Flutter, .NET, Unity).
///
/// These methods are public for consumption by wrapper SDKs that bridge
/// between native and managed runtimes. They may change, be renamed,
/// or be removed in any minor release without prior deprecation.
///
/// App developers: prefer the standard @c SentryObjCSDK API surface instead.
@interface SentryObjCInternalApi : NSObject
SENTRY_NO_INIT

/// SDK metadata and configuration.
@property (nonatomic, readonly) SentryObjCInternalSdkApi *sdk;

/// Debug image access for symbolication.
@property (nonatomic, readonly) SentryObjCInternalDebugApi *debug;

/// Breadcrumb creation from dictionary representation.
@property (nonatomic, readonly) SentryObjCInternalBreadcrumbApi *breadcrumbs;

/// User creation from dictionary representation.
@property (nonatomic, readonly) SentryObjCInternalUserApi *user;

/// Envelope store, capture, and deserialization.
@property (nonatomic, readonly) SentryObjCInternalEnvelopeApi *envelope;

/// Method swizzling.
@property (nonatomic, readonly) SentryObjCInternalSwizzleApi *swizzle;

/// App start measurement.
@property (nonatomic, readonly) SentryObjCInternalAppStartApi *appStart;

#if SENTRY_OBJC_HAS_UIKIT
/// Frame tracking performance metrics.
@property (nonatomic, readonly) SentryObjCInternalPerformanceApi *performance;

#    if !TARGET_OS_VISION
/// Screenshot capture.
@property (nonatomic, readonly) SentryObjCInternalScreenshotApi *screenshot;

/// View hierarchy capture.
@property (nonatomic, readonly) SentryObjCInternalViewHierarchyApi *viewHierarchy;

/// Screen name tracking.
@property (nonatomic, readonly) SentryObjCInternalScreenApi *screen;
#    endif
#endif

#if SENTRY_OBJC_REPLAY_SUPPORTED
/// Session replay.
@property (nonatomic, readonly) SentryObjCInternalReplayApi *replay;
#endif

#if SENTRY_OBJC_PROFILING_SUPPORTED
/// Profiling.
@property (nonatomic, readonly) SentryObjCInternalProfilingApi *profiling;
#endif

/// Sets the current trace and span on the scope's propagation context.
- (void)setTrace:(SentryObjCId *)traceId spanId:(SentryObjCSpanId *)spanId;

/// Sets a custom log output handler for SDK log messages.
- (void)setLogOutput:(void (^_Nullable)(NSString *))output;

/// Tells the crash reporter to ignore the next signal on the calling thread.
- (void)ignoreNextSignal:(int)signum;

/// Returns the current SDK options, or a default instance if the SDK has not been started.
@property (nonatomic, readonly) SentryObjCOptions *options;

/// Creates SDK options from a dictionary representation.
- (nullable SentryObjCOptions *)optionsFromDictionary:(NSDictionary<NSString *, id> *)dictionary
                                                error:(NSError *_Nullable *_Nullable)error;

@end

NS_ASSUME_NONNULL_END
