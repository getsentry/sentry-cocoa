#import <SentryHttpStatusCodeRange.h>

NS_ASSUME_NONNULL_BEGIN

@implementation SentryHttpStatusCodeRange

- (instancetype)initWithMin:(NSNumber *)min andMax:(NSNumber *)max {
    if (self = [super init]) {
        _min = min;
        _max = max;
    }
    return self;
}

- (instancetype)initWithStatusCode:(NSNumber *)statusCode {
    if (self = [super init]) {
        _min = statusCode;
        _max = statusCode;
    }
    return self;
}

- (BOOL)isInRange:(NSNumber *)statusCode {
    return statusCode >= _min && statusCode <= _max;
}

@end

NS_ASSUME_NONNULL_END
