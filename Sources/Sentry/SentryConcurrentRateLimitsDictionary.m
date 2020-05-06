#import <Foundation/Foundation.h>
#import "SentryConcurrentRateLimitsDictionary.h"

@interface SentryConcurrentRateLimitsDictionary()

/* Key is the type and value is valid until date */
@property(nonatomic, strong) NSMutableDictionary<NSNumber *, NSDate *> *rateLimits;

@end

@implementation SentryConcurrentRateLimitsDictionary

- (instancetype)init {
    if (self = [super init]) {
        self.rateLimits = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (void)addRateLimits:(NSDictionary<NSNumber *, NSDate *> *)rateLimits {
    @synchronized (self.rateLimits) {
        [self.rateLimits addEntriesFromDictionary:rateLimits];
    }
}

- (NSDate *)getRateLimitForCategory:(SentryRateLimitCategory)category {
    @synchronized (self.rateLimits) {
        return self.rateLimits[[NSNumber numberWithInt:category]];
    }
}

@end
