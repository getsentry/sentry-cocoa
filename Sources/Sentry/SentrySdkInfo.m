#import "SentrySdkInfo.h"
#import "SentryClient+Private.h"
#import "SentryHub+Private.h"
#import "SentryMeta.h"
#import "SentryOptions.h"
#import "SentrySDK+Private.h"
#import "SentrySwift.h"
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

static NSSet<NSDictionary<NSString *, NSString *> *> *extraPackages;

NS_ASSUME_NONNULL_BEGIN

@interface SentrySdkInfo ()
@end

@implementation SentrySdkInfo

+ (void)addPackageName:(NSString *)name version:(NSString *)version
{
    if (name == nil || version == nil) {
        return;
    }

    @synchronized(extraPackages) {
        NSDictionary<NSString *, NSString *> *newPackage =
            @{ @"name" : name, @"version" : version };
        if (extraPackages == nil) {
            extraPackages = [[NSSet alloc] initWithObjects:newPackage, nil];
        } else {
            extraPackages = [extraPackages setByAddingObject:newPackage];
        }
    }
}

+ (NSMutableSet<NSDictionary<NSString *, NSString *> *> *)getExtraPackages
{
    @synchronized(extraPackages) {
        if (extraPackages == nil) {
            return [[NSMutableSet alloc] init];
        } else {
            return [extraPackages mutableCopy];
        }
    }
}

#if TEST || TESTCI
+ (void)clearExtraPackages
{
    extraPackages = [[NSSet alloc] init];
}

+ (void)setPackageManager:(NSUInteger)manager
{
    SENTRY_PACKAGE_INFO = manager;
}

+ (void)resetPackageManager
{
    SENTRY_PACKAGE_INFO = SentryPackageManagerUnkown;
}
#endif

+ (nullable NSString *)getSentrySDKPackageName:(SentryPackageManagerOption)packageManager
{
    switch (packageManager) {
    case SentrySwiftPackageManager:
        return [NSString stringWithFormat:@"spm:getsentry/%@", SentryMeta.sdkName];
    case SentryCocoaPods:
        return [NSString stringWithFormat:@"cocoapods:getsentry/%@", SentryMeta.sdkName];
    case SentryCarthage:
        return [NSString stringWithFormat:@"carthage:getsentry/%@", SentryMeta.sdkName];
    default:
        return nil;
    }
}

+ (nullable NSDictionary<NSString *, NSString *> *)getSentrySDKPackage:
    (SentryPackageManagerOption)packageManager
{

    if (packageManager == SentryPackageManagerUnkown) {
        return nil;
    }

    NSString *name = [SentrySdkInfo getSentrySDKPackageName:packageManager];
    if (nil == name) {
        return nil;
    }

    return @{ @"name" : name, @"version" : SentryMeta.versionString };
}

+ (nullable NSDictionary<NSString *, NSString *> *)getSentrySDKPackage
{
    return [SentrySdkInfo getSentrySDKPackage:SENTRY_PACKAGE_INFO];
}

+ (instancetype)fromGlobals
{
    return [[SentrySdkInfo alloc] initWithOptions:[SentrySDK.currentHub getClient].options];
}

- (instancetype)initWithOptions:(SentryOptions *)options
{

    NSArray<NSString *> *features =
        [SentryEnabledFeaturesBuilder getEnabledFeaturesWithOptions:options];

    NSMutableArray<NSString *> *integrations =
        [SentrySDK.currentHub trimmedInstalledIntegrationNames];

#if SENTRY_HAS_UIKIT
    if (options.enablePreWarmedAppStartTracing) {
        [integrations addObject:@"PreWarmedAppStartTracing"];
    }
#endif

    NSMutableSet<NSDictionary<NSString *, NSString *> *> *packages =
        [SentrySdkInfo getExtraPackages];
    [packages addObject:[SentrySdkInfo getSentrySDKPackage]];

    return [self initWithName:SentryMeta.sdkName
                      version:SentryMeta.versionString
                 integrations:integrations
                     features:features
                     packages:[packages allObjects]];
}

- (instancetype)initWithName:(NSString *)name
                     version:(NSString *)version
                integrations:(NSArray<NSString *> *)integrations
                    features:(NSArray<NSString *> *)features
                    packages:(NSArray<NSDictionary<NSString *, NSString *> *> *)packages
{
    if (self = [super init]) {
        _name = name ?: @"";
        _version = version ?: @"";
        _integrations = integrations ?: @[];
        _features = features ?: @[];
        _packages = packages ?: @[];
    }

    return self;
}

- (instancetype)initWithDict:(NSDictionary *)dict
{
    NSString *name = @"";
    NSString *version = @"";
    NSMutableSet<NSString *> *integrations = [[NSMutableSet alloc] init];
    NSMutableSet<NSString *> *features = [[NSMutableSet alloc] init];
    NSMutableSet<NSDictionary<NSString *, NSString *> *> *packages = [[NSMutableSet alloc] init];

    if ([dict[@"name"] isKindOfClass:[NSString class]]) {
        name = dict[@"name"];
    }

    if ([dict[@"version"] isKindOfClass:[NSString class]]) {
        version = dict[@"version"];
    }

    if ([dict[@"integrations"] isKindOfClass:[NSArray class]]) {
        for (id item in dict[@"integrations"]) {
            if ([item isKindOfClass:[NSString class]]) {
                [integrations addObject:item];
            }
        }
    }

    if ([dict[@"features"] isKindOfClass:[NSArray class]]) {
        for (id item in dict[@"features"]) {
            if ([item isKindOfClass:[NSString class]]) {
                [features addObject:item];
            }
        }
    }

    if ([dict[@"packages"] isKindOfClass:[NSArray class]]) {
        for (id item in dict[@"packages"]) {
            if ([item isKindOfClass:[NSDictionary class]] &&
                [item[@"name"] isKindOfClass:[NSString class]] &&
                [item[@"version"] isKindOfClass:[NSString class]]) {
                [packages addObject:@{ @"name" : item[@"name"], @"version" : item[@"version"] }];
            }
        }
    }

    return [self initWithName:name
                      version:version
                 integrations:[integrations allObjects]
                     features:[features allObjects]
                     packages:[packages allObjects]];
}

- (nullable NSString *)getPackageName:(SentryPackageManagerOption)packageManager
{
    switch (packageManager) {
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

- (NSDictionary<NSString *, id> *)serialize
{
    return @{
        @"name" : self.name,
        @"version" : self.version,
        @"integrations" : self.integrations,
        @"features" : self.features,
        @"packages" : self.packages,
    };
}

@end

NS_ASSUME_NONNULL_END
