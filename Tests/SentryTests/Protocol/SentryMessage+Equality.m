#import "SentryMessage+Equality.h"

@implementation
SentryMessage (Equality)

- (BOOL)isEqual:(id)other
{
    if (other == self)
        return YES;
    if (!other || ![[other class] isEqual:[self class]])
        return NO;

    return [self isEqualToMessage:other];
}

- (BOOL)isEqualToMessage:(SentryMessage *)message
{
    if (self == message)
        return YES;
    if (message == nil)
        return NO;
    if (self.formatted != message.formatted && ![self.formatted isEqualToString:message.formatted])
        return NO;
    if (self.message != message.message && ![self.message isEqualToString:message.message])
        return NO;
    if (self.params != message.params && ![self.params isEqualToArray:message.params])
        return NO;

    return YES;
}

- (NSUInteger)hash
{
    NSUInteger hash = 17;

    hash = hash * 23 + [self.formatted hash];
    hash = hash * 23 + [self.message hash];
    hash = hash * 23 + [self.params hash];

    return hash;
}

@end
