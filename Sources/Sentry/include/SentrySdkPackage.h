#if __has_include(<Sentry/SentryDefines.h>)
#    import <Sentry/SentryDefines.h>
#else
#    import "SentryDefines.h"
#endif

#if __has_include(<Sentry/SentryInternalSerializable.h>)
#    import <Sentry/SentryInternalSerializable.h>
#else
#    import "SentryInternalSerializable.h"
#endif

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Describes the Sentry SDK Package
 * @note Both name and version are required.
 * @see https://develop.sentry.dev/sdk/event-payloads/sdk/
 */
@interface SentrySdkPackage : NSObject <SentryInternalSerializable>
SENTRY_NO_INIT

- (instancetype)initWithName:(NSString *)name
                  andVersion:(NSString *)version NS_DESIGNATED_INITIALIZER;

/**
 * Initialize Package frrom serialized dictionary if possible else returns nil
 */
- (nullable instancetype)initWithDict:(NSDictionary *)dict;

/**
 * The package name. Examples: spm:getsentry/sentry.cocoa, npm:@sentry/react-native, ...
 */
@property (nonatomic, readonly, copy) NSString *name;

/**
 * The version of the packge. It should have the Semantic Versioning format MAJOR.MINOR.PATCH,
 * without any prefix (no v or anything else in front of the major version number). Examples:
 * 0.1.0, 1.0.0, 2.0.0-beta0
 */
@property (nonatomic, readonly, copy) NSString *version;

/**
 * Returns current Sentry Cocoa SDK package.
 */
+ (nullable instancetype)getSentrySDKPackage;

#if TEST
+ (void)setSentryPackageInfoForTests:(NSUInteger)value;
#endif

@end

NS_ASSUME_NONNULL_END
