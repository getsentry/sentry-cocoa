#import <Foundation/Foundation.h>
#import <SentryObjC/SentryObjCDefines.h>

#if SENTRY_OBJC_HAS_UIKIT

NS_ASSUME_NONNULL_BEGIN

/// Screen name APIs for Sentry hybrid SDKs.
///
/// These methods may change in any minor release without deprecation.
@interface SentryObjCInternalScreenApi : NSObject

/// Sets the name of the current screen on the scope.
- (void)setCurrent:(nullable NSString *)screenName;

@end

NS_ASSUME_NONNULL_END

#endif
