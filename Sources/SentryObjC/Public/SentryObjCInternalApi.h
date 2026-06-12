#import <Foundation/Foundation.h>
#if !__has_include(<SentryObjC/SentryObjCDefines.h>)
#    import "SentryObjCDefines.h"
#else
#    import <SentryObjC/SentryObjCDefines.h>
#endif

@class SentryObjCId;
@class SentryObjCSpanId;
@class SentryObjCOptions;
@class SentryObjCInternalReplayApi;
@class SentryObjCInternalProfilingApi;
@class SentryObjCInternalAppStartApi;
@class SentryObjCInternalPerformanceApi;
@class SentryObjCInternalScreenshotApi;
@class SentryObjCInternalViewHierarchyApi;
@class SentryObjCInternalEnvelopeApi;
@class SentryObjCInternalScreenApi;
@class SentryObjCInternalSwizzleApi;
@class SentryObjCInternalSdkApi;
@class SentryObjCInternalDebugApi;
@class SentryObjCInternalBreadcrumbApi;
@class SentryObjCInternalUserApi;

NS_ASSUME_NONNULL_BEGIN

/// APIs intended for Sentry hybrid SDKs (React Native, Flutter, .NET, Unity).
///
/// These methods are public for consumption by wrapper SDKs that bridge
/// between native and managed runtimes. They may change, be renamed,
/// or be removed in any minor release without prior deprecation.
///
/// App developers: prefer the standard @c SentryObjCSDK API surface instead.
@interface SentryObjCInternalApi : NSObject

// MARK: - Sub-object Accessors

#if SENTRY_OBJC_REPLAY_SUPPORTED
@property (nonatomic, readonly) SentryObjCInternalReplayApi *replay;
@property (nonatomic, readonly) SentryObjCInternalPerformanceApi *performance;
@property (nonatomic, readonly) SentryObjCInternalScreenshotApi *screenshot;
@property (nonatomic, readonly) SentryObjCInternalViewHierarchyApi *viewHierarchy;
@property (nonatomic, readonly) SentryObjCInternalScreenApi *screen;
#endif

@property (nonatomic, readonly) SentryObjCInternalAppStartApi *appStart;
@property (nonatomic, readonly) SentryObjCInternalEnvelopeApi *envelope;
@property (nonatomic, readonly) SentryObjCInternalSwizzleApi *swizzle;
@property (nonatomic, readonly) SentryObjCInternalSdkApi *sdk;
@property (nonatomic, readonly) SentryObjCInternalDebugApi *debug;
@property (nonatomic, readonly) SentryObjCInternalBreadcrumbApi *breadcrumbs;
@property (nonatomic, readonly) SentryObjCInternalUserApi *user;

// MARK: - Direct Methods

/// Sets the current trace and span ID on the scope.
- (void)setTrace:(SentryObjCId *)traceId spanId:(SentryObjCSpanId *)spanId;

/// Sets a custom log output handler.
- (void)setLogOutput:(void (^)(NSString *))output;

/// Tells the crash reporter to ignore the next occurrence of the given signal.
- (void)ignoreNextSignal:(int)signum;

/// The current SDK options.
@property (nonatomic, readonly) SentryObjCOptions *options;

/// Creates options from a dictionary.
- (nullable SentryObjCOptions *)optionsFromDictionary:(NSDictionary<NSString *, id> *)dictionary
                                                error:(NSError *_Nullable *_Nullable)error;

@end

NS_ASSUME_NONNULL_END
