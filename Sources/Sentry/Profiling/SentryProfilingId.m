#import "SentryProfilingId.h"

@implementation SentryProfilingId

- (instancetype)init
{
    return [self initWithUUID:[[NSUUID alloc] init]];
}

- (instancetype)initWithUUID:(NSUUID *)uuid
{
    if (self = [super init]) {
        _uuid = uuid;
        _stringValue = [[uuid.UUIDString stringByReplacingOccurrencesOfString:@"-"
                                                                   withString:@""] lowercaseString];
    }
    return self;
}

- (BOOL)isEqual:(id)object
{
    if (object == self) {
        return YES;
    }
    if (![object isKindOfClass:[SentryProfilingId class]]) {
        return NO;
    }
    return [self.uuid isEqual:((SentryProfilingId *)object).uuid];
}

- (NSUInteger)hash
{
    return self.uuid.hash;
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

- (NSString *)description
{
    return self.stringValue;
}

@end
