#import <Foundation/Foundation.h>
#if !__has_include(<SentryObjC/SentryObjCDefines.h>)
#    import "SentryObjCDefines.h"
#else
#    import <SentryObjC/SentryObjCDefines.h>
#endif

#if SENTRY_OBJC_HAS_UIKIT

NS_ASSUME_NONNULL_BEGIN

/// Screenshot capture APIs for Sentry hybrid SDKs.
///
/// These methods may change in any minor release without deprecation.
@interface SentryObjCInternalScreenshotApi : NSObject
SENTRY_NO_INIT

/// Captures screenshots of all application windows.
- (nullable NSArray<NSData *> *)capture;

@end

NS_ASSUME_NONNULL_END

#endif
