#import <Foundation/Foundation.h>
#import <SentryObjC/SentryObjCDefines.h>

#if SENTRY_OBJC_HAS_UIKIT

NS_ASSUME_NONNULL_BEGIN

/// Performance/frames tracking APIs for Sentry hybrid SDKs.
///
/// These methods may change in any minor release without deprecation.
@interface SentryObjCInternalPerformanceApi : NSObject

/// Enables frame tracking measurements in hybrid SDK mode.
@property (nonatomic, assign) BOOL framesTrackingHybridSDKMode;

/// Whether the frames tracker is currently running.
@property (nonatomic, readonly) BOOL isFramesTrackingRunning;

@end

NS_ASSUME_NONNULL_END

#endif
