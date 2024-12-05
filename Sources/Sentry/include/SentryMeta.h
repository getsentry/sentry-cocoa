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
 * Return an array of Serialized SDK packages
 */
+ (NSArray<NSDictionary<NSString *, NSString *> *> *)getSdkPackagesSerialized;

/**
 * Return an array of SDK packages present in the runtime
 */
+ (NSSet<SentrySdkPackage *> *)getSdkPackages;

/**
 * Add a SDK package to the set of SDK packages
 */
+ (void)addSdkPackage:(NSString *_Nonnull)name version:(NSString *_Nonnull)version;

#if TEST
/**
 * Clear all SDK packages. For testing purposes only.
 */
+ (void)clearSdkPackages;
#endif

@end

NS_ASSUME_NONNULL_END
