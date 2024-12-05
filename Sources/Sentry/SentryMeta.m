#import "SentryMeta.h"

@implementation SentryMeta

// Don't remove the static keyword. If you do the compiler adds the constant name to the global
// symbol table and it might clash with other constants. When keeping the static keyword the
// compiler replaces all occurrences with the value.
static NSString *versionString = @"8.42.0-beta.1";
static NSString *sdkName = @"sentry.cocoa";

static NSSet<SentrySdkPackage *> *sdkPackages;

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

+ (NSArray<NSDictionary<NSString *, NSString *> *> *)getSdkPackagesSerialized
{
    NSMutableArray *serializedPackages = [NSMutableArray array];
    for (SentrySdkPackage *package in [self getSdkPackages]) {
        [serializedPackages addObject:[package serialize]];
    }
    return serializedPackages;
}

+ (NSSet<SentrySdkPackage *> *)getSdkPackages
{
    @synchronized(self) {
        if (sdkPackages == nil) {
            [self initializeSdkPackages];
        }
        return sdkPackages;
    }
}

+ (void)addSdkPackage:(NSString *_Nonnull)name version:(NSString *_Nonnull)version
{
    @synchronized(self) {
        if (sdkPackages == nil) {
            [self initializeSdkPackages];
        }
        sdkPackages = [sdkPackages
            setByAddingObject:[[SentrySdkPackage alloc] initWithName:name andVersion:version]];
    }
}

+ (void)initializeSdkPackages
{
    SentrySdkPackage *sdkPackage = [SentrySdkPackage getSentrySDKPackage];
    if (nil == sdkPackage) {
        sdkPackages = [NSSet set];
        return;
    }

    sdkPackages = [NSSet setWithObject:sdkPackage];
}

#if TEST
+ (void)clearSdkPackages
{
    sdkPackages = nil;
}
#endif

@end
