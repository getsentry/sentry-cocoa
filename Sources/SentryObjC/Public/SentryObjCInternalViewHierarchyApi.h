#import <Foundation/Foundation.h>
#import <SentryObjC/SentryObjCDefines.h>

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
