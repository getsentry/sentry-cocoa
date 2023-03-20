#import "SentryUser.h"
#import "NSDictionary+SentrySanitize.h"

NS_ASSUME_NONNULL_BEGIN

@implementation SentryUser

- (instancetype)initWithUserId:(NSString *)userId
{
    self = [super init];
    if (self) {
        self.userId = userId;
    }
    return self;
}

- (instancetype)init
{
    return [super init];
}

- (id)copyWithZone:(nullable NSZone *)zone
{
    SentryUser *copy = [[SentryUser allocWithZone:zone] init];

    if (copy != nil) {
        copy.userId = self.userId;
        copy.email = self.email;
        copy.username = self.username;
        copy.ipAddress = self.ipAddress;
        copy.segment = self.segment;
        copy.geo = self.geo.copy;
        copy.data = self.data.copy;
    }

    return copy;
}

- (NSDictionary<NSString *, id> *)serialize
{
    NSMutableDictionary *serializedData = [[NSMutableDictionary alloc] init];

    [serializedData setValue:self.userId forKey:@"id"];
    [serializedData setValue:self.email forKey:@"email"];
    [serializedData setValue:self.username forKey:@"username"];
    [serializedData setValue:self.ipAddress forKey:@"ip_address"];
    [serializedData setValue:self.segment forKey:@"segment"];
    [serializedData setValue:[self.geo serialize] forKey:@"geo"];
    [serializedData setValue:[self.data sentry_sanitize] forKey:@"data"];

    return serializedData;
}

- (BOOL)isEqual:(id _Nullable)other
{

    if (other == self) {
        return YES;
    }
    if (!other || ![[other class] isEqual:[self class]]) {
        return NO;
    }

    return [self isEqualToUser:other];
}

- (BOOL)isEqualToUser:(SentryUser *)user
{
    if (self == user) {
        return YES;
    }
    if (user == nil) {
        return NO;
    }

    NSString *otherUserId = user.userId;
    if (self.userId != otherUserId && ![self.userId isEqualToString:otherUserId]) {
        return NO;
    }

    NSString *otherEmail = user.email;
    if (self.email != otherEmail && ![self.email isEqualToString:otherEmail]) {
        return NO;
    }

    NSString *otherUsername = user.username;
    if (self.username != otherUsername && ![self.username isEqualToString:otherUsername]) {
        return NO;
    }

    NSString *otherIpAdress = user.ipAddress;
    if (self.ipAddress != otherIpAdress && ![self.ipAddress isEqualToString:otherIpAdress]) {
        return NO;
    }

    NSString *otherSegment = user.segment;
    if (self.segment != otherSegment && ![self.segment isEqualToString:otherSegment]) {
        return NO;
    }

    SentryGeo *otherGeo = user.geo;
    if (self.geo != otherGeo && ![self.geo isEqualToGeo:otherGeo]) {
        return NO;
    }

    NSDictionary<NSString *, id> *otherUserData = user.data;
    if (self.data != otherUserData && ![self.data isEqualToDictionary:otherUserData]) {
        return NO;
    }

    return YES;
}

- (NSUInteger)hash
{
    NSUInteger hash = 17;

    hash = hash * 23 + [self.userId hash];
    hash = hash * 23 + [self.email hash];
    hash = hash * 23 + [self.username hash];
    hash = hash * 23 + [self.ipAddress hash];
    hash = hash * 23 + [self.segment hash];
    hash = hash * 23 + [self.geo hash];
    hash = hash * 23 + [self.data hash];

    return hash;
}

@end

NS_ASSUME_NONNULL_END
