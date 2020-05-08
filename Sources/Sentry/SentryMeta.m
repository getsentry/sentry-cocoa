#import "SentryMeta.h"

@implementation SentryMeta

NSString *const versionString = @"5.0.2";
NSString *const sdkName = @"sentry.cocoa";

+ (NSString *)versionString {
    return versionString;
}

+ (NSString *)sdkName {
    return sdkName;
}

@end
