#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// SDK metadata APIs for Sentry hybrid SDKs.
///
/// These methods may change in any minor release without deprecation.
@interface SentryObjCInternalSdkApi : NSObject

/// The current SDK name.
@property (nonatomic, copy) NSString *name;

/// The current SDK version string.
@property (nonatomic, copy) NSString *versionString;

/// Overrides the SDK name and version string in one call.
- (void)setName:(NSString *)name version:(NSString *)version;

/// Adds a package to the SDK's package list.
- (void)addPackageName:(NSString *)name version:(NSString *)version;

/// Extra context information.
@property (nonatomic, readonly, copy) NSDictionary<NSString *, id> *extraContext;

/// The unique installation ID.
@property (nonatomic, readonly, copy) NSString *installationID;

@end

NS_ASSUME_NONNULL_END
