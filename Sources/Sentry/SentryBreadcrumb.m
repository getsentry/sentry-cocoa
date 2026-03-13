#import "SentryBreadcrumb.h"
#import "SentryBreadcrumb+Private.h"
#import "SentryDateUtils.h"
#import "SentryInternalDefines.h"
#import "SentryLevel.h"
#import "SentryLevelMapper.h"
#import "SentryNSDictionarySanitize.h"
#import "SentrySwift.h"

/**
 * Recursively copies a value, producing immutable collections at every level.
 * For @c NSDictionary / @c NSArray (including mutable subclasses) a new immutable copy is
 * returned with all nested containers copied as well. Other values are returned as-is.
 * This prevents the SDK from holding references to caller-owned mutable objects whose
 * concurrent mutation would crash serialization (see
 * https://github.com/getsentry/sentry-cocoa/issues/2601).
 */
static id
sentry_deepCopyValue(id value)
{
    if ([value isKindOfClass:[NSDictionary class]]) {
        // Defensive copy to prevent mutation during enumeration.
        NSDictionary *dictionaryCopy = [(NSDictionary *)value copy];
        NSMutableDictionary *result =
            [NSMutableDictionary dictionaryWithCapacity:dictionaryCopy.count];
        for (id key in dictionaryCopy) {
            id v = dictionaryCopy[key];
            if (v != nil) {
                result[key] = sentry_deepCopyValue(v);
            }
        }
        return [result copy]; // immutable
    } else if ([value isKindOfClass:[NSArray class]]) {
        // Defensive copy to prevent mutation during enumeration.
        NSArray *arrayCopy = [(NSArray *)value copy];
        NSMutableArray *result = [NSMutableArray arrayWithCapacity:arrayCopy.count];
        for (id item in arrayCopy) {
            [result addObject:sentry_deepCopyValue(item)];
        }
        return [result copy]; // immutable
    }
    return value;
}

@implementation SentryBreadcrumb

// Explicit @synthesize so we can provide thread-safe accessors via @synchronized(self).
@synthesize level = _level;
@synthesize category = _category;
@synthesize timestamp = _timestamp;
@synthesize type = _type;
@synthesize message = _message;
@synthesize origin = _origin;
@synthesize data = _data;

#pragma mark - Thread-safe property accessors

- (void)setLevel:(SentryLevel)level
{
    @synchronized(self) {
        _level = level;
    }
}

- (SentryLevel)level
{
    @synchronized(self) {
        return _level;
    }
}

- (void)setCategory:(NSString *)category
{
    @synchronized(self) {
        _category = [category copy];
    }
}

- (NSString *)category
{
    @synchronized(self) {
        return _category;
    }
}

- (void)setTimestamp:(NSDate *)timestamp
{
    @synchronized(self) {
        _timestamp = timestamp;
    }
}

- (NSDate *)timestamp
{
    @synchronized(self) {
        return _timestamp;
    }
}

- (void)setType:(NSString *)type
{
    @synchronized(self) {
        _type = [type copy];
    }
}

- (NSString *)type
{
    @synchronized(self) {
        return _type;
    }
}

- (void)setMessage:(NSString *)message
{
    @synchronized(self) {
        _message = [message copy];
    }
}

- (NSString *)message
{
    @synchronized(self) {
        return _message;
    }
}

- (void)setOrigin:(NSString *)origin
{
    @synchronized(self) {
        _origin = [origin copy];
    }
}

- (NSString *)origin
{
    @synchronized(self) {
        return _origin;
    }
}

- (void)setData:(NSDictionary<NSString *, id> *)data
{
    @synchronized(self) {
        _data = data ? sentry_deepCopyValue(data) : nil;
    }
}

- (NSDictionary<NSString *, id> *)data
{
    @synchronized(self) {
        return _data;
    }
}

#pragma mark - Initializers

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

- (instancetype)initWithLevel:(SentryLevel)level category:(NSString *)category
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

#pragma mark - Serialization

- (NSDictionary<NSString *, id> *)serialize
{
    // Capture all properties under the lock to get a consistent snapshot.
    SentryLevel level;
    NSDate *timestamp;
    NSString *category;
    NSString *type;
    NSString *origin;
    NSString *message;
    NSDictionary *data;

    @synchronized(self) {
        level = _level;
        timestamp = _timestamp;
        category = _category;
        type = _type;
        origin = _origin;
        message = _message;
        data = _data;
    }

    NSMutableDictionary *serializedData = [[NSMutableDictionary alloc] init];

    [serializedData setValue:nameForSentryLevel(level) forKey:@"level"];
    if (timestamp != nil) {
        [serializedData setValue:sentry_toIso8601String(SENTRY_UNWRAP_NULLABLE(NSDate, timestamp))
                          forKey:@"timestamp"];
    }
    [serializedData setValue:category forKey:@"category"];
    [serializedData setValue:type forKey:@"type"];
    [serializedData setValue:origin forKey:@"origin"];
    [serializedData setValue:message forKey:@"message"];
    [serializedData setValue:sentry_sanitize(data) forKey:@"data"];
    return serializedData;
}

#pragma mark - Equality

- (BOOL)isEqual:(id _Nullable)other
{
    if (other == self)
        return YES;
    if (!other || ![other isKindOfClass:[SentryBreadcrumb class]])
        return NO;

    return [self isEqualToBreadcrumb:SENTRY_UNWRAP_NULLABLE(SentryBreadcrumb, other)];
}

- (BOOL)isEqualToBreadcrumb:(SentryBreadcrumb *)breadcrumb
{
    if (self == breadcrumb)
        return YES;
    if (breadcrumb == nil)
        return NO;
    if (self.level != breadcrumb.level)
        return NO;
    if (self.category != breadcrumb.category
        && ![self.category isEqualToString:breadcrumb.category])
        return NO;
    if (self.timestamp != breadcrumb.timestamp
        && ![self.timestamp isEqualToDate:SENTRY_UNWRAP_NULLABLE(NSDate, breadcrumb.timestamp)])
        return NO;
    if (self.type != breadcrumb.type
        && ![self.type isEqualToString:SENTRY_UNWRAP_NULLABLE(NSString, breadcrumb.type)])
        return NO;
    if (self.origin != breadcrumb.origin
        && ![self.origin isEqualToString:SENTRY_UNWRAP_NULLABLE(NSString, breadcrumb.origin)])
        return NO;
    if (self.message != breadcrumb.message
        && ![self.message isEqualToString:SENTRY_UNWRAP_NULLABLE(NSString, breadcrumb.message)])
        return NO;
    if (self.data != breadcrumb.data
        && ![self.data isEqualToDictionary:SENTRY_UNWRAP_NULLABLE(NSDictionary, breadcrumb.data)])
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
