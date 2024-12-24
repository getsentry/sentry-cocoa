#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentryMeta : NSObject

/**
 * Return a version string e.g: 1.2.3 (3)
 */
@property (nonatomic, class, copy) NSString *versionString;

/**
 * Return a string sentry-cocoa
 */
@property (nonatomic, class, copy) NSString *sdkName;

/**
 * Return a version string e.g: 1.2.3 (3)
 * This always report the version of Sentry.cocoa,
 * `versionString` can be changed by hybrid SDKs.
 * We can use this property to get which version of Sentry cocoa
 * the hybrid SDK is using.
 */
@property (nonatomic, class, readonly) NSString *nativeVersionString;

/**
 * Returns "sentry.cocoa"
 * `sdkName` can be changed by hybrid SDKs.
 */
@property (nonatomic, class, readonly) NSString *nativeSdkName;

@end

NS_ASSUME_NONNULL_END
