#import <Foundation/Foundation.h>
#import "SentryRateLimitParser.h"
#import "SentryCurrentDate.h"

NS_ASSUME_NONNULL_BEGIN

@interface SentryRateLimitParser ()

@end

@implementation SentryRateLimitParser

+ (NSDictionary<NSString *, NSDate *> * _Nonnull)parse:(NSString *)header {
    
    NSMutableDictionary<NSString *, NSDate *> *rateLimits = [[NSMutableDictionary alloc] init];
    
    if ([header length] == 0)  {
        return rateLimits;
    }
    
    NSString *headerNoWhitespaces = [self removeAllWhitespaces:header];
    
    NSArray<NSString *> *quotas = [headerNoWhitespaces componentsSeparatedByString:@","];
    for (NSString* quota in quotas) {
        
        NSArray<NSString *> *parameters = [quota componentsSeparatedByString:@":"];
        
        NSNumber *retryAfterInSeconds = [self getRetryAfterInSeconds:parameters[0]];
        if (nil == retryAfterInSeconds || [retryAfterInSeconds intValue] <= 0) {
            continue;
        }
        
        NSArray<NSString *> *categories =  [parameters[1] componentsSeparatedByString:@";"];
        for (NSString *category in categories) {
            rateLimits[category] = [SentryCurrentDate.date dateByAddingTimeInterval:[retryAfterInSeconds doubleValue]];
        }
    }
    
    return rateLimits;
}

+ (NSString *)removeAllWhitespaces:(NSString *)string {
    NSArray *words = [string componentsSeparatedByCharactersInSet :[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return [words componentsJoinedByString:@""];
}

+ (NSNumber *)getRetryAfterInSeconds:(NSString *)string {
    NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
    numberFormatter.numberStyle = NSNumberFormatterNoStyle;
    return [numberFormatter numberFromString:string];
}

@end

NS_ASSUME_NONNULL_END
