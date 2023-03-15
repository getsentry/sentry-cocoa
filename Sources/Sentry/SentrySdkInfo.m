#import "SentrySdkInfo.h"
#import <Foundation/Foundation.h>


/**
 * This is required to identify the package manager used when installing sentry.
 */
#if SWIFT_PACKAGE
static NSString *SENTRY_PACKAGE_INFO = @"spm:getsentry/%@";
#elif COCOAPODS
static NSString *SENTRY_PACKAGE_INFO = @"cocoapods:getsentry/%@";
#elif CARTHAGE_YES
static NSString *SENTRY_PACKAGE_INFO = @"carthage:getsentry/%@";
#elif TEST
static NSString *SENTRY_PACKAGE_INFO = @"TEST:getsentry/%@";
#else
static NSString *SENTRY_PACKAGE_INFO = nil;
#endif

NS_ASSUME_NONNULL_BEGIN

@implementation SentrySdkInfo

- (instancetype)initWithName:(NSString *)name andVersion:(NSString *)version
{
    if (self = [super init]) {
        _name = name ?: @"";
        _version = version ?: @"";
    }

    return self;
}

- (instancetype)initWithDict:(NSDictionary *)dict
{
    return [self initWithDictInternal:dict orDefaults:nil];
}

- (instancetype)initWithDict:(NSDictionary *)dict orDefaults:(SentrySdkInfo *)info;
{
    return [self initWithDictInternal:dict orDefaults:info];
}

- (instancetype)initWithDictInternal:(NSDictionary *)dict orDefaults:(SentrySdkInfo *_Nullable)info;
{
    NSString *name = @"";
    NSString *version = @"";

    if (nil != dict[@"sdk"] && [dict[@"sdk"] isKindOfClass:[NSDictionary class]]) {
        NSDictionary<NSString *, id> *sdkInfoDict = dict[@"sdk"];
        if ([sdkInfoDict[@"name"] isKindOfClass:[NSString class]]) {
            name = sdkInfoDict[@"name"];
        } else if (info && info.name) {
            name = info.name;
        }

        if ([sdkInfoDict[@"version"] isKindOfClass:[NSString class]]) {
            version = sdkInfoDict[@"version"];
        } else if (info && info.version) {
            version = info.version;
        }
    }

    return [self initWithName:name andVersion:version];
}

- (NSDictionary<NSString *, id> *)serialize
{
    NSMutableDictionary *sdk = @{
        @"name" : self.name,
        @"version" : self.version,
    }
                                   .mutableCopy;
    if (SENTRY_PACKAGE_INFO != nil) {
        sdk[@"packages"] = @{
            @"name" : [NSString stringWithFormat:SENTRY_PACKAGE_INFO, self.name],
            @"version" : self.version
        };
    }

    return @{ @"sdk" : sdk };
}

@end

NS_ASSUME_NONNULL_END
