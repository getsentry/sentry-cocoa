#import <Foundation/Foundation.h>

#import "SentrySerializable.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Describes the system SDK.
 */
@interface SentrySdkInfo : NSObject <SentrySerializable>
SENTRY_NO_INIT

@property (nonatomic, readonly, copy) NSString *_Nullable sdkName;

@property (nonatomic, readonly, copy) NSNumber *_Nullable versionMajor;

@property (nonatomic, readonly, copy) NSNumber *_Nullable versionMinor;

@property (nonatomic, readonly, copy) NSNumber *_Nullable versionPatchLevel;

- (instancetype)initWithSdkName:(NSString *)sdkName andVersionString:(NSString *)versionString;

- (instancetype _Nullable)initWithDict:(NSDictionary *)dict;

@end

NS_ASSUME_NONNULL_END
