#import "SentrySDKSettings.h"
#import "SentryOptions.h"
#import "SentrySDKInternal.h"

@implementation SentrySDKSettings

- (instancetype)initWithOptions:(SentryOptions *_Nullable)options
{
    if (self = [super init]) {
        _autoInferIP = options.sendDefaultPii;
    }

    return self;
}

- (instancetype)initWithDict:(NSDictionary *)dict
{
    if (self = [super init]) {
        if ([dict[@"infer_ip"] isKindOfClass:[NSString class]]) {
            _autoInferIP = [dict[@"infer_ip"] isEqualToString:@"auto"];
        }
    }
    return self;
}

- (nonnull NSDictionary<NSString *, id> *)serialize
{
    return @{ @"infer_ip" : _autoInferIP ? @"auto" : @"never" };
}

@end
