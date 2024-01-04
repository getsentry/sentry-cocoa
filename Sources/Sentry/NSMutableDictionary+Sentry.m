#import "NSMutableDictionary+Sentry.h"

@implementation
NSMutableDictionary (Sentry)

+ (void)load
{
    NSLog(@"%llu %s", clock_gettime_nsec_np(CLOCK_UPTIME_RAW), __PRETTY_FUNCTION__);
}

- (void)mergeEntriesFromDictionary:(NSDictionary *)otherDictionary
{
    [otherDictionary enumerateKeysAndObjectsUsingBlock:^(id otherKey, id otherObj, BOOL *stop) {
        if ([otherObj isKindOfClass:NSDictionary.class] &&
            [self[otherKey] isKindOfClass:NSDictionary.class]) {
            NSMutableDictionary *mergedDict = ((NSDictionary *)self[otherKey]).mutableCopy;
            [mergedDict mergeEntriesFromDictionary:(NSDictionary *)otherObj];
            self[otherKey] = mergedDict;
            return;
        }

        self[otherKey] = otherObj;
    }];
}

- (void)setBoolValue:(nullable NSNumber *)value forKey:(NSString *)key
{
    if (value != nil) {
        [self setValue:@([value boolValue]) forKey:key];
    }
}

@end
