#import "SentrySdkInfo.h"
#import "SentryClient+Private.h"
#import "SentryHub+Private.h"
#import "SentryInternalDefines.h"
#import "SentryMeta.h"
#import "SentryOptions.h"
#import "SentrySDK+Private.h"
#import "SentrySDKSettings.h"
#import "SentrySwift.h"

NS_ASSUME_NONNULL_BEGIN

@interface SentrySdkInfo ()
@end

@implementation SentrySdkInfo

+ (instancetype)global
{
    SentryClient *_Nullable client = [SentrySDKInternal.currentHub getClient];
    return [[SentrySdkInfo alloc] initWithOptions:client.options];
}

- (instancetype)initWithOptions:(SentryOptions *_Nullable)options
{

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    NSArray<NSString *> *features =
        [SentryEnabledFeaturesBuilder getEnabledFeaturesWithOptions:options];
#pragma clang diagnostic pop

    NSMutableArray<NSString *> *integrations =
        [SentrySDKInternal.currentHub trimmedInstalledIntegrationNames];

#if SENTRY_HAS_UIKIT
    if (options.enablePreWarmedAppStartTracing) {
        [integrations addObject:@"PreWarmedAppStartTracing"];
    }
#endif

    NSMutableSet<NSDictionary<NSString *, NSString *> *> *packages =
        [SentryExtraPackages getPackages];
    NSDictionary<NSString *, NSString *> *sdkPackage = [SentrySdkPackage global];
    if (sdkPackage != nil) {
        [packages addObject:sdkPackage];
    }
    SentrySDKSettings *settings = [[SentrySDKSettings alloc] initWithOptions:options];

    return [self initWithName:SentryMeta.sdkName
                      version:SentryMeta.versionString
                 integrations:integrations
                     features:features
                     packages:[packages allObjects]
                     settings:settings];
}

- (instancetype)initWithName:(NSString *)name
                     version:(NSString *)version
                integrations:(NSArray<NSString *> *)integrations
                    features:(NSArray<NSString *> *)features
                    packages:(NSArray<NSDictionary<NSString *, NSString *> *> *)packages
                    settings:(SentrySDKSettings *)settings
{
    if (self = [super init]) {
        _name = name ?: @"";
        _version = version ?: @"";
        _integrations = integrations ?: @[];
        _features = features ?: @[];
        _packages = packages ?: @[];
        _settings = settings;
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
    SentrySDKSettings *settings = [[SentrySDKSettings alloc] initWithDict:@{}];

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

    if (dict[@"settings"] && [dict[@"settings"] isKindOfClass:[NSDictionary class]]) {
        settings = [[SentrySDKSettings alloc]
            initWithDict:SENTRY_UNWRAP_NULLABLE(NSDictionary, dict[@"settings"])];
    }

    return [self initWithName:name
                      version:version
                 integrations:[integrations allObjects]
                     features:[features allObjects]
                     packages:[packages allObjects]
                     settings:settings];
}

- (NSDictionary<NSString *, id> *)serialize
{
    return @{
        @"name" : self.name,
        @"version" : self.version,
        @"integrations" : self.integrations,
        @"features" : self.features,
        @"packages" : self.packages,
        @"settings" : [self.settings serialize]
    };
}

@end

NS_ASSUME_NONNULL_END
