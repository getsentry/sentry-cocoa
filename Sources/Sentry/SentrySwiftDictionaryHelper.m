#import "SentrySwiftDictionaryHelper.h"

@implementation SentrySwiftDictionaryHelper

+ (NSDictionary<NSString *, id> *)convertDictionaryToObjc:(NSDictionary<NSString *, id> *)input
{
    return [NSDictionary dictionaryWithDictionary:input];
}

+ (NSDictionary<NSString *, id> *)convertFrom:(NSString *)name
                                      version:(NSString *)version
                                 integrations:(id)integrations
                                     features:(id)features
                                     packages:(id)packages
{
    return @{
        @"name" : name,
        @"version" : version,
        @"integrations" : integrations,
        @"features" : features,
        @"packages" : packages,
    };
}

@end
