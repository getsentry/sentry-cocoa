#import <Foundation/Foundation.h>
#if !__has_include(<SentryObjC/SentryObjCDefines.h>)
#    import "SentryObjCDefines.h"
#else
#    import <SentryObjC/SentryObjCDefines.h>
#endif

#if SENTRY_OBJC_HAS_UIKIT && !TARGET_OS_VISION

NS_ASSUME_NONNULL_BEGIN

/// Screen tracking APIs for Sentry hybrid SDKs.
///
/// These methods may change in any minor release without deprecation.
@interface SentryObjCInternalScreenApi : NSObject
SENTRY_NO_INIT

/// Sets the current screen name on the SDK scope.
- (void)setCurrent:(nullable NSString *)screenName;

@end

NS_ASSUME_NONNULL_END

#endif
