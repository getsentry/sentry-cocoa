#import <Foundation/Foundation.h>
#if !__has_include(<SentryObjC/SentryObjCDefines.h>)
#    import "SentryObjCDefines.h"
#else
#    import <SentryObjC/SentryObjCDefines.h>
#endif

#if SENTRY_OBJC_HAS_UIKIT

NS_ASSUME_NONNULL_BEGIN

/// Frame tracking performance APIs for Sentry hybrid SDKs.
///
/// These methods may change in any minor release without deprecation.
@interface SentryObjCInternalPerformanceApi : NSObject
SENTRY_NO_INIT

/// Whether frames tracking is operating in hybrid SDK mode.
@property (nonatomic) BOOL framesTrackingHybridSDKMode;

/// Whether frames tracking is currently running.
@property (nonatomic, readonly) BOOL isFramesTrackingRunning;

@end

NS_ASSUME_NONNULL_END

#endif
