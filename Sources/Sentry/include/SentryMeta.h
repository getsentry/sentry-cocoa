#import "SentrySdkPackage.h"
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
 * Return an array of SDK packages present in the runtime
 */
+ (NSSet<SentrySdkPackage *> *)sdkPackages;

/**
 * Add a SDK package to the set of SDK packages
 */
+ (void)addSdkPackage:(SentrySdkPackage *)value;

@end

NS_ASSUME_NONNULL_END
