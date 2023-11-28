#import "SentryNSError.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@implementation SentryNSError

+ (void)load
{
    printf("%llu %s\n", clock_gettime_nsec_np(CLOCK_UPTIME_RAW), __PRETTY_FUNCTION__);
}

- (instancetype)initWithDomain:(NSString *)domain code:(NSInteger)code
{
    if (self = [super init]) {
        _domain = domain;
        _code = code;
    }
    return self;
}

- (NSDictionary<NSString *, id> *)serialize
{
    return @{ @"domain" : self.domain, @"code" : @(self.code) };
}

@end

NS_ASSUME_NONNULL_END
