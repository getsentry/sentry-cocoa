#import "SentryNetworkBody.h"

@implementation SentryNetworkBody

- (instancetype)initWithBody:(nullable id)body
{
    return [self initWithBody:body warnings:nil];
}

- (instancetype)initWithBody:(nullable id)body warnings:(nullable NSArray<NSNumber *> *)warnings
{
    if (self = [super init]) {
        _body = body;
        _warnings = warnings;
    }
    return self;
}

- (NSDictionary *)serialize
{
    NSMutableDictionary *result = [NSMutableDictionary dictionary];

    if (self.body) {
        result[@"body"] = self.body;
    }

    if (self.warnings && self.warnings.count > 0) {
        NSMutableArray *warningStrings = [NSMutableArray arrayWithCapacity:self.warnings.count];
        for (NSNumber *warningNumber in self.warnings) {
            SentryNetworkBodyWarning warning
                = (SentryNetworkBodyWarning)[warningNumber integerValue];
            [warningStrings addObject:SentryNetworkBodyWarningToString(warning)];
        }
        result[@"warnings"] = warningStrings;
    }

    return result;
}

@end