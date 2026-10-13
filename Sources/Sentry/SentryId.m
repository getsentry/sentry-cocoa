#import "SentryId.h"
#import "SentryId+Private.h"

@interface SentryId ()

@property (nonatomic) NSUUID *id;

@end

@implementation SentryId

+ (SentryId *)empty
{
    return [[SentryId alloc] initWithUUIDString:@"00000000-0000-0000-0000-000000000000"];
}

- (nonnull instancetype)init
{
    if (self = [super init]) {
        self.id = NSUUID.UUID;
        return self;
    }
    return nil;
}

- (BOOL)isEqual:(id _Nullable)object
{
    if ([object isKindOfClass:[SentryId class]]) {
        return [self.id isEqual:((SentryId *)object).id];
    }
    return NO;
}

- (NSString *)sentryIdString
{
    return [self.id.UUIDString stringByReplacingOccurrencesOfString:@"-" withString:@""]
        .lowercaseString;
}

- (nonnull instancetype)initWithUuid:(NSUUID *_Nonnull)uuid
{
    if (self = [super init]) {
        self.id = uuid;
        return self;
    }
    return nil;
}

+ (nullable NSUUID *)sentry_parseUUIDString:(NSString *)uuidString
{
    NSUUID *parsed = [[NSUUID alloc] initWithUUIDString:uuidString];
    if (parsed != nil || uuidString.length != 32) {
        return parsed;
    }

    NSMutableString *dashed = [NSMutableString stringWithCapacity:36];
    for (NSUInteger i = 0; i < uuidString.length; i++) {
        if (i == 8 || i == 12 || i == 16 || i == 20) {
            [dashed appendString:@"-"];
        }
        [dashed appendFormat:@"%C", [uuidString characterAtIndex:i]];
    }
    return [[NSUUID alloc] initWithUUIDString:dashed];
}

- (nonnull instancetype)initWithUUIDString:(NSString *_Nonnull)uuidString
{
    if (self = [super init]) {
        NSUUID *parsed = [SentryId sentry_parseUUIDString:uuidString];
        if (parsed != nil) {
            self.id = parsed;
            return self;
        }

        // Preserve the public initializer's historical fallback for invalid input.
        NSUUID *zero = [[NSUUID alloc] initWithUUIDString:@"00000000-0000-0000-0000-000000000000"];
        self.id = zero ?: [NSUUID UUID];
        return self;
    }
    return nil;
}

- (NSUInteger)hash
{
    return self.id.hash;
}

- (NSString *)description
{
    return self.sentryIdString;
}

@end
