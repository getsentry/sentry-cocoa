#import <Foundation/Foundation.h>

#import "SentryEnvelope.h"

@class SentryOptions;

NS_ASSUME_NONNULL_BEGIN

/**
 * SPI (System Programming Interface) for hybrid SDK wrappers.
 *
 * This class exposes internal SDK functionality needed by
 * React Native, Flutter, .NET, Unity, and Unreal SDK wrappers.
 */
@interface PrivateSentrySDKOnly : NSObject

+ (void)setSdkName:(NSString *)sdkName;
+ (void)setSdkName:(NSString *)sdkName andVersionString:(NSString *)versionString;
+ (NSString *)getSdkName;
+ (NSString *)getSdkVersionString;

@property (class, nonatomic, readonly, copy) SentryOptions *options;

+ (void)captureEnvelope:(SentryEnvelope *)envelope;
+ (void)storeEnvelope:(SentryEnvelope *)envelope;

@property (class, nonatomic, readonly, copy) NSString *installationID;

@end

NS_ASSUME_NONNULL_END
