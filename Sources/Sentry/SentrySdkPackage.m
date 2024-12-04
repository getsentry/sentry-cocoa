#import "SentrySdkPackage.h"
#import "SentryMeta.h"
#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, SentryPackageManagerOption) {
    SentrySwiftPackageManager,
    SentryCocoaPods,
    SentryCarthage,
    SentryPackageManagerUnkown
};

/**
 * This is required to identify the package manager used when installing sentry.
 */
#if SWIFT_PACKAGE
static SentryPackageManagerOption SENTRY_PACKAGE_INFO = SentrySwiftPackageManager;
#elif COCOAPODS
static SentryPackageManagerOption SENTRY_PACKAGE_INFO = SentryCocoaPods;
#elif CARTHAGE_YES
// CARTHAGE is a xcodebuild build setting with value `YES`, we need to convert it into a compiler
// definition to be able to use it.
static SentryPackageManagerOption SENTRY_PACKAGE_INFO = SentryCarthage;
#else
static SentryPackageManagerOption SENTRY_PACKAGE_INFO = SentryPackageManagerUnkown;
#endif

NS_ASSUME_NONNULL_BEGIN

@interface SentrySdkPackage ()

@property (nonatomic) SentryPackageManagerOption packageManager;

@end

@implementation SentrySdkPackage

- (instancetype)initWithName:(NSString *)name andVersion:(NSString *)version
{
    if (self = [super init]) {
        _name = name ?: @"";
        _version = version ?: @"";
        _packageManager = SENTRY_PACKAGE_INFO;
    }

    return self;
}

- (nullable instancetype)initWithDict:(NSDictionary *)dict
{
    NSString *name = @"";
    NSString *version = @"";

    if (![dict[@"name"] isKindOfClass:[NSString class]]) {
        return nil;
    } else {
        name = dict[@"name"];
    }

    if (![dict[@"version"] isKindOfClass:[NSString class]]) {
        return nil;
    } else {
        version = dict[@"version"];
    }

    return [self initWithName:name andVersion:version];
}

- (NSDictionary<NSString *, id> *)serialize
{
    return @{
        @"name" : self.name,
        @"version" : self.version,
    };
}

+ (nullable NSString *)getSentrySDKPackageName
{
    switch (SENTRY_PACKAGE_INFO) {
    case SentrySwiftPackageManager:
        return @"spm:getsentry/%@";
    case SentryCocoaPods:
        return @"cocoapods:getsentry/%@";
    case SentryCarthage:
        return @"carthage:getsentry/%@";
    default:
        return nil;
    }
}

+ (nullable SentrySdkPackage *)getSentrySDKPackage
{

    if (SENTRY_PACKAGE_INFO == SentryPackageManagerUnkown) {
        return nil;
    }

    NSString *name = [SentrySdkPackage getSentrySDKPackageName];
    if (nil == name) {
        return nil;
    }

    return [[SentrySdkPackage alloc] initWithName:name andVersion:SentryMeta.versionString];
}

@end

NS_ASSUME_NONNULL_END
