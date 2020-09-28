#import "SentryBreadcrumb.h"
#import "NSDate+SentryExtras.h"
#import "NSDictionary+SentrySanitize.h"

@implementation SentryBreadcrumb

- (instancetype)initWithLevel:(enum SentryLevel)level category:(NSString *)category
{
    self = [super init];
    if (self) {
        self.level = level;
        self.category = category;
        self.timestamp = [NSDate date];
    }
    return self;
}

- (instancetype)init
{
    return [self initWithLevel:kSentryLevelInfo category:@"default"];
}

- (NSDictionary<NSString *, id> *)serialize
{
    NSMutableDictionary *serializedData = [NSMutableDictionary new];

    [serializedData setValue:SentryLevelNames[self.level] forKey:@"level"];
    [serializedData setValue:[self.timestamp sentry_toIso8601String] forKey:@"timestamp"];
    [serializedData setValue:self.category forKey:@"category"];
    [serializedData setValue:self.type forKey:@"type"];
    [serializedData setValue:self.message forKey:@"message"];
    [serializedData setValue:[self.data sentry_sanitize] forKey:@"data"];

    return serializedData;
}

- (BOOL)isEqual:(id)other
{
    if (other == self)
        return YES;
    if (!other || ![[other class] isEqual:[self class]])
        return NO;

    return [self isEqualToBreadcrumb:other];
}

- (BOOL)isEqualToBreadcrumb:(SentryBreadcrumb *)breadcrumb
{
    if (self == breadcrumb)
        return YES;
    if (breadcrumb == nil)
        return NO;
    if (self.level != breadcrumb.level)
        return NO;
    if (self.category != breadcrumb.category)
        return NO;
    if (self.timestamp != breadcrumb.timestamp
        && ![self.timestamp isEqualToDate:breadcrumb.timestamp])
        return NO;
    if (self.type != breadcrumb.type)
        return NO;
    if (self.message != breadcrumb.message)
        return NO;
    if (self.data != breadcrumb.data && ![self.data isEqualToDictionary:breadcrumb.data])
        return NO;
    return YES;
}

- (NSUInteger)hash
{

    NSUInteger hash = 17;

    hash = hash * 23 + (NSUInteger)self.level;
    hash = hash * 23 + (NSUInteger)self.category;
    hash = hash * 23 + [self.timestamp hash];
    hash = hash * 23 + (NSUInteger)self.type;
    hash = hash * 23 + (NSUInteger)self.message;
    hash = hash * 23 + [self.data hash];
    return hash;
}

@end
