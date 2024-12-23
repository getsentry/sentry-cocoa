#import "SentryMeta.h"

@implementation SentryMeta


const NSString * const sentryVersionString = @"8.43.0-beta.1";
const NSString * const sentrySdkName = @"sentry.cocoa";

// Don't remove the static keyword. If you do the compiler adds the constant name to the global
// symbol table and it might clash with other constants. When keeping the static keyword the
// compiler replaces all occurrences with the value.
static NSString *versionString;
static NSString *sdkName;

+ (void)initialize {
    versionString = sentryVersionString.copy;
    sdkName = sentrySdkName.copy;
}

+ (NSString *)versionString
{
    return versionString;
}

+ (void)setVersionString:(NSString *)value
{
    versionString = value;
}

+ (NSString *)sdkName
{
    return sdkName;
}

+ (void)setSdkName:(NSString *)value
{
    sdkName = value;
}

+ (NSString*)nativeSdkName {
    return sentrySdkName.copy;
}

+ (NSString*)nativeVersionString {
    return sentryVersionString.copy;
}


@end
