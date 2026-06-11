#import <Foundation/Foundation.h>
#import <SentryObjC/SentryObjCDefines.h>

@class SentryObjCId;
@class SentryObjCSpanId;
@class SentryObjCUser;
@class SentryObjCBreadcrumb;
@class SentryObjCOptions;
@class SentryObjCDebugMeta;
@class SentryObjCEnvelope;
@class SentryObjCInternalReplayApi;
@class SentryObjCInternalProfilingApi;
@class SentryObjCInternalAppStartApi;
@class SentryObjCInternalPerformanceApi;
@class SentryObjCInternalScreenshotApi;
@class SentryObjCInternalViewHierarchyApi;
@class SentryObjCInternalEnvelopeApi;
@class SentryObjCInternalScreenApi;
@class SentryObjCInternalSwizzleApi;

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

// MARK: - Direct Methods

/// Creates a @c SentryObjCUser from a dictionary.
- (SentryObjCUser *)userWithDictionary:(NSDictionary *)dictionary;

/// Creates a @c SentryObjCBreadcrumb from a dictionary.
- (SentryObjCBreadcrumb *)breadcrumbWithDictionary:(NSDictionary *)dictionary;

/// Sets the current trace and span ID on the scope.
- (void)setTrace:(SentryObjCId *)traceId spanId:(SentryObjCSpanId *)spanId;

/// Sets a custom log output handler.
- (void)setLogOutput:(void (^)(NSString *))output;

/// Tells the crash reporter to ignore the next occurrence of the given signal.
- (void)ignoreNextSignal:(int)signum;

/// Overrides the SDK name and version string.
- (void)setSdkName:(NSString *)name version:(NSString *)version;

/// Overrides the SDK name only.
- (void)setSdkName:(NSString *)name;

/// The current SDK name.
@property (nonatomic, readonly, copy) NSString *sdkName;

/// The current SDK version string.
@property (nonatomic, readonly, copy) NSString *sdkVersionString;

/// Adds a package to the SDK's package list.
- (void)addSdkPackageName:(NSString *)name version:(NSString *)version;

/// Extra context information.
@property (nonatomic, readonly, copy) NSDictionary<NSString *, id> *extraContext;

/// The unique installation ID.
@property (nonatomic, readonly, copy) NSString *installationID;

/// The current SDK options.
@property (nonatomic, readonly) SentryObjCOptions *options;

/// Creates options from a dictionary.
- (nullable SentryObjCOptions *)optionsFromDictionary:(NSDictionary<NSString *, id> *)dictionary
                                                error:(NSError *_Nullable *_Nullable)error;

/// All debug images currently loaded by the process.
@property (nonatomic, readonly, copy) NSArray<SentryObjCDebugMeta *> *debugImages;

/// Debug images for the given raw memory addresses.
- (NSArray<SentryObjCDebugMeta *> *)debugImagesForAddresses:(NSArray<NSNumber *> *)addresses;

@end

NS_ASSUME_NONNULL_END
