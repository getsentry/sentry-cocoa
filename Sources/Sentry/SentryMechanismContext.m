#import "SentryMechanismContext.h"
#import "SentryNSError.h"
#import "SentrySanitizerUtils.h"

NS_ASSUME_NONNULL_BEGIN

@implementation SentryMechanismContext

- (instancetype)init
{
    self = [super init];
    return self;
}

- (NSDictionary<NSString *, id> *)serialize
{
    NSMutableDictionary<NSString *, id> *data = [[NSMutableDictionary alloc] init];

    data[@"signal"] = sentry_sanitize_dictionary(self.signal);
    data[@"mach_exception"] = sentry_sanitize_dictionary(self.machException);
    data[@"ns_error"] = [self.error serialize];

    return data;
}

@end

NS_ASSUME_NONNULL_END
