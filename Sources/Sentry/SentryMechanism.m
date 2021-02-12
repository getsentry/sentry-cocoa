#import "SentryMechanism.h"
#import "SentryNSError.h"

NS_ASSUME_NONNULL_BEGIN

@implementation SentryMechanism

- (instancetype)initWithType:(NSString *)type
{
    self = [super init];
    if (self) {
        self.type = type;
    }
    return self;
}

- (NSDictionary<NSString *, id> *)serialize
{
    NSMutableDictionary *serializedData = @{ @"type" : self.type }.mutableCopy;

    [serializedData setValue:self.handled forKey:@"handled"];
    [serializedData setValue:self.desc forKey:@"description"];
    [serializedData setValue:self.meta forKey:@"meta"];
    [serializedData setValue:self.data forKey:@"data"];
    [serializedData setValue:self.helpLink forKey:@"help_link"];

    if (nil != self.error) {
        serializedData[@"ns_error"] = [self.error serialize];
    }

    return serializedData;
}

@end

NS_ASSUME_NONNULL_END
