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

NS_ASSUME_NONNULL_BEGIN

@interface SentrySdkInfo ()

@property (nonatomic) SentryPackageManagerOption packageManager;

@end

@implementation SentrySdkInfo

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

    return [self initWithName:SentryMeta.sdkName
                      version:SentryMeta.versionString
                 integrations:integrations
                     features:features];
}

- (instancetype)initWithName:(NSString *)name
                     version:(NSString *)version
                integrations:(NSArray<NSString *> *)integrations
                    features:(NSArray<NSString *> *)features
{
    if (self = [super init]) {
        _name = name ?: @"";
        _version = version ?: @"";
        _packageManager = SENTRY_PACKAGE_INFO;
        _integrations = integrations ?: @[];
        _features = features ?: @[];
    }

    return self;
}

- (instancetype)initWithDict:(NSDictionary *)dict
{
    NSString *name = @"";
    NSString *version = @"";
    NSMutableSet<NSString *> *integrations = [[NSMutableSet alloc] init];
    NSMutableSet<NSString *> *features = [[NSMutableSet alloc] init];

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

    return [self initWithName:name
                      version:version
                 integrations:[integrations allObjects]
                     features:[features allObjects]];
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
    NSMutableDictionary *sdk = @{
        @"name" : self.name,
        @"version" : self.version,
        @"integrations" : self.integrations,
        @"features" : self.features,
    }
                                   .mutableCopy;
    if (self.packageManager != SentryPackageManagerUnkown) {
        NSString *format = [self getPackageName:self.packageManager];
        if (format != nil) {
            sdk[@"packages"] = @[
                @{
                    @"name" : [NSString stringWithFormat:format, self.name],
                    @"version" : self.version
                },
            ];
        }
    }

    return sdk;
}

@end

NS_ASSUME_NONNULL_END
