#import "SentryDefines.h"
#import "SentryOptionsObjC.h"
#import "SentryProfilingConditionals.h"
#import <Foundation/Foundation.h>

#if SENTRY_HAS_UIKIT
#    import <UIKit/UIKit.h>
#endif // SENTRY_HAS_UIKIT

@class SentryHubInternal;
@class SentryDispatchQueueWrapper;

NS_ASSUME_NONNULL_BEGIN

@interface SentryDefaultRedactOptions : NSObject

@property (nonatomic) BOOL maskAllText;
@property (nonatomic) BOOL maskAllImages;
@property (nonatomic) NSArray<Class> *maskedViewClasses;
@property (nonatomic) NSArray<Class> *unmaskedViewClasses;

@end

// Some Swift code needs to access Sentry types that we don’t want to completely
// expose to Swift. This class is exposed to Swift
// and bridges some functionality from without importing large amounts of the
// codebase to Swift.
@interface SentryDependencyContainerSwiftHelper : NSObject

#if SENTRY_HAS_UIKIT

+ (nullable NSArray<UIWindow *> *)windows;

// Since SentryOptions is in ObjC, Swift code can't see the SentryViewScreenshotOptions property
+ (BOOL)fastViewRenderingEnabled:(SentryOptionsObjC *)options;
+ (BOOL)viewRendererV2Enabled:(SentryOptionsObjC *)options;
+ (SentryDefaultRedactOptions *)redactOptions:(SentryOptionsObjC *)options;
+ (int)getSessionReplayMaskingStrategy:(SentryOptionsObjC *)options;

#endif // SENTRY_HAS_UIKIT

+ (NSString *_Nullable)release:(SentryOptionsObjC *)options;
+ (NSString *)environment:(SentryOptionsObjC *)options;
+ (NSObject *_Nullable)beforeSendLog:(NSObject *)beforeSendLog options:(SentryOptionsObjC *)options;
+ (NSString *)cacheDirectoryPath:(SentryOptionsObjC *)options;
+ (BOOL)enableLogs:(SentryOptionsObjC *)options;
+ (NSArray<NSString *> *)enabledFeatures:(SentryOptionsObjC *)options;
+ (BOOL)sendDefaultPii:(SentryOptionsObjC *)options;
+ (NSArray<NSString *> *)inAppIncludes:(SentryOptionsObjC *)options;

+ (SentryDispatchQueueWrapper *)dispatchQueueWrapper;
+ (void)dispatchSyncOnMainQueue:(void (^)(void))block;
+ (nullable NSDate *)readTimestampLastInForeground;
+ (void)deleteTimestampLastInForeground;
+ (void)storeTimestampLastInForeground:(NSDate *)timestamp;

#if SENTRY_TARGET_PROFILING_SUPPORTED
+ (BOOL)hasProfilingOptions;
#endif

@end

NS_ASSUME_NONNULL_END
