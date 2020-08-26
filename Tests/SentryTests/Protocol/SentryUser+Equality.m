#import "SentryUser+Equality.h"

@implementation SentryUser (Equality)

- (BOOL)isEqual:(id)other
{
    if (other == self)
        return YES;
    if (!other || ![[other class] isEqual:[self class]])
        return NO;

    return [self isEqualToUser:other];
}

- (BOOL)isEqualToUser:(SentryUser *)user
{
    if (self == user)
        return YES;
    if (user == nil)
        return NO;
    if (self.userId != user.userId && ![self.userId isEqualToString:user.userId])
        return NO;
    if (self.email != user.email && ![self.email isEqualToString:user.email])
        return NO;
    if (self.username != user.username && ![self.username isEqualToString:user.username])
        return NO;
    if (self.ipAddress != user.ipAddress && ![self.ipAddress isEqualToString:user.ipAddress])
        return NO;
    if (self.data != user.data && ![self.data isEqualToDictionary:user.data])
        return NO;
    return YES;
}

- (NSUInteger)hash
{
    NSUInteger hash = 17;

    hash = hash * 23 + [self.userId hash];
    hash = hash * 23 + [self.email hash];
    hash = hash * 23 + [self.username hash];
    hash = hash * 23 + [self.ipAddress hash];
    hash = hash * 23 + [self.data hash];

    return hash;
}

@end
