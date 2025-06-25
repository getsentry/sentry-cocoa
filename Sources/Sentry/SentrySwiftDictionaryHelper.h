#import <Foundation/Foundation.h>

@interface SentrySwiftDictionaryHelper : NSObject

+ (NSDictionary<NSString *, id> *)convertDictionaryToObjc:(NSDictionary<NSString *, id> *)input;

+ (NSDictionary<NSString *, id> *)convertFrom:(NSString *)name
                                      version:(NSString *)version
                                 integrations:(id)integrations
                                     features:(id)features
                                     packages:(id)packages;

@end
