#import <Foundation/Foundation.h>
#if !__has_include(<SentryObjC/SentryObjCDefines.h>)
#    import "SentryObjCDefines.h"
#else
#    import <SentryObjC/SentryObjCDefines.h>
#endif

#if SENTRY_OBJC_HAS_UIKIT

NS_ASSUME_NONNULL_BEGIN

/// Screenshot APIs for Sentry hybrid SDKs.
///
/// These methods may change in any minor release without deprecation.
@interface SentryObjCInternalScreenshotApi : NSObject

/// Captures screenshots of the current application windows.
/// @return An array of PNG screenshot data, or @c nil if unavailable.
- (nullable NSArray<NSData *> *)capture;

@end

NS_ASSUME_NONNULL_END

#endif
