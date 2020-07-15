#import <Foundation/Foundation.h>

#import "SentrySerializable.h"

NS_ASSUME_NONNULL_BEGIN

@interface SentrySdkInfo : NSObject <SentrySerializable>

@property (nonatomic, readonly, copy) NSString *_Nullable sdkName;

@property (nonatomic, readonly, copy) NSNumber *_Nullable versionMajor;

@property (nonatomic, readonly, copy) NSNumber *_Nullable versionMinor;

@property (nonatomic, readonly, copy) NSNumber *_Nullable versionPatchLevel;

- (instancetype)initWithSdkName:(NSString *)sdkName andVersionString:(NSString *)versionString;

@end

NS_ASSUME_NONNULL_END
