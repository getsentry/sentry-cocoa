#import "SentryBreadcrumb.h"
#import "SentryBreadcrumb+Private.h"
#import "SentryDateUtils.h"
#import "SentryLevelMapper.h"
#import "SentryNSDictionarySanitize.h"
#import "SentrySwift.h"

@implementation SentryBreadcrumb

- (instancetype)initWithDictionary:(NSDictionary *)dictionary
{
    if (self = [super init]) {
        for (id key in dictionary) {
            id value = [dictionary valueForKey:key];
            if (value == nil) {
                continue;
            }
            BOOL isString = [value isKindOfClass:[NSString class]];
            BOOL isDictionary = [value isKindOfClass:[NSDictionary class]];

            if ([key isEqualToString:@"level"] && isString) {
                self.level = sentryLevelForString(value);
            } else if ([key isEqualToString:@"timestamp"] && isString) {
                self.timestamp = sentry_fromIso8601String(value);
            } else if ([key isEqualToString:@"category"] && isString) {
                self.category = value;
            } else if ([key isEqualToString:@"type"] && isString) {
                self.type = value;
            } else if ([key isEqualToString:@"origin"] && isString) {
                self.origin = value;
            } else if ([key isEqualToString:@"message"] && isString) {
                self.message = value;
            } else if ([key isEqualToString:@"data"] && isDictionary) {
                self.data = value;
            }
        }
    }
    return self;
}

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

    [serializedData setValue:nameForSentryLevel(self.level) forKey:@"level"];
    if (self.timestamp != nil) {
        [serializedData setValue:sentry_toIso8601String((NSDate *_Nonnull)self.timestamp)
                          forKey:@"timestamp"];
    }
    [serializedData setValue:self.category forKey:@"category"];
    [serializedData setValue:self.type forKey:@"type"];
    [serializedData setValue:self.origin forKey:@"origin"];
    [serializedData setValue:self.message forKey:@"message"];
    [serializedData setValue:sentry_sanitize(self.data) forKey:@"data"];
    return serializedData;
}

- (BOOL)isEqual:(id _Nullable)other
{
    if (other == self)
        return YES;
    if (!other || ![[other class] isEqual:[self class]])
        return NO;

    if ([other isKindOfClass:[SentryBreadcrumb class]]) {
        return [self isEqualToBreadcrumb:other];
    }
    return NO;
}

- (BOOL)isEqualToBreadcrumb:(SentryBreadcrumb *_Nullable)breadcrumb
{
    if (self == breadcrumb)
        return YES;
    if (breadcrumb == nil)
        return NO;
    if (self.level != breadcrumb.level)
        return NO;
    if (self.category != breadcrumb.category
        && ![self.category isEqualToString:(NSString *_Nonnull)breadcrumb.category])
        return NO;
    if (self.timestamp != breadcrumb.timestamp && breadcrumb.timestamp != nil
        && self.timestamp != nil) {
        if (![self.timestamp isEqualToDate:(NSDate *_Nonnull)breadcrumb.timestamp]) {
            return NO;
        }
    } else if (self.timestamp != breadcrumb.timestamp)
        return NO;
    if (self.type != breadcrumb.type && breadcrumb.type != nil && self.type != nil) {
        if (![self.type isEqualToString:(NSString *_Nonnull)breadcrumb.type]) {
            return NO;
        }
    } else if (self.type != breadcrumb.type)
        return NO;
    if (self.origin != breadcrumb.origin && breadcrumb.origin != nil && self.origin != nil) {
        if (![self.origin isEqualToString:(NSString *_Nonnull)breadcrumb.origin]) {
            return NO;
        }
    } else if (self.origin != breadcrumb.origin)
        return NO;
    if (self.message != breadcrumb.message && breadcrumb.message != nil && self.message != nil) {
        if (![self.message isEqualToString:(NSString *_Nonnull)breadcrumb.message]) {
            return NO;
        }
    } else if (self.message != breadcrumb.message)
        return NO;
    if (self.data != breadcrumb.data && breadcrumb.data != nil && self.data != nil) {
        if (![self.data isEqualToDictionary:(NSDictionary *_Nonnull)breadcrumb.data]) {
            return NO;
        }
    } else if (self.data != breadcrumb.data)
        return NO;
    return YES;
}

- (NSUInteger)hash
{
    NSUInteger hash = 17;
    hash = hash * 23 + (NSUInteger)self.level;
    hash = hash * 23 + [self.category hash];
    hash = hash * 23 + [self.timestamp hash];
    hash = hash * 23 + [self.type hash];
    hash = hash * 23 + [self.origin hash];
    hash = hash * 23 + [self.message hash];
    hash = hash * 23 + [self.data hash];
    return hash;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p, %@>", [self class], self, [self serialize]];
}

@end
