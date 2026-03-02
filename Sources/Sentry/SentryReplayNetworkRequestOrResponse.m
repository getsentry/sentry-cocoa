#import "SentryReplayNetworkRequestOrResponse.h"

@implementation SentryReplayNetworkRequestOrResponse

- (instancetype)initWithSize:(nullable NSNumber *)size
                        body:(nullable SentryNetworkBody *)body
                     headers:(NSDictionary<NSString *, NSString *> *)headers
{
    if (self = [super init]) {
        _size = size;
        _body = body;
        _headers = [headers copy] ?: @{};
    }
    return self;
}

- (NSDictionary *)serialize
{
    NSMutableDictionary *result = [NSMutableDictionary dictionary];

    if (self.size) {
        result[@"size"] = self.size;
    }

    if (self.body) {
        result[@"body"] = [self.body serialize];
    }

    result[@"headers"] = self.headers;

    return result;
}

@end