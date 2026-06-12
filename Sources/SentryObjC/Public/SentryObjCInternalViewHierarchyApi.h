#import <Foundation/Foundation.h>
#if !__has_include(<SentryObjC/SentryObjCDefines.h>)
#    import "SentryObjCDefines.h"
#else
#    import <SentryObjC/SentryObjCDefines.h>
#endif

#if SENTRY_OBJC_HAS_UIKIT

NS_ASSUME_NONNULL_BEGIN

/// View hierarchy APIs for Sentry hybrid SDKs.
///
/// These methods may change in any minor release without deprecation.
@interface SentryObjCInternalViewHierarchyApi : NSObject

/// Captures the current view hierarchy.
/// @return JSON data representing the view hierarchy, or @c nil if unavailable.
- (nullable NSData *)capture;

@end

NS_ASSUME_NONNULL_END

#endif
