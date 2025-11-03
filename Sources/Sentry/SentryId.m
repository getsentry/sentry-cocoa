#import "SentryId.h"

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

- (nonnull instancetype)initWithUUIDString:(NSString *_Nonnull)uuidString
{
    if (self = [super init]) {
        // Try to create UUID directly from the provided string
        NSUUID *parsed = [[NSUUID alloc] initWithUUIDString:uuidString];
        if (parsed != nil) {
            self.id = parsed;
            return self;
        }

        // If it's a 32-char hex string, insert dashes at 8-12-16-20 and try again
        if (uuidString.length == 32) {
            // Ensure the characters are hex; if not, we still attempt formatting like the Swift
            // code
            NSMutableString *dashed = [NSMutableString stringWithCapacity:36];
            for (NSUInteger i = 0; i < uuidString.length; i++) {
                if (i == 8 || i == 12 || i == 16 || i == 20) {
                    [dashed appendString:@"-"];
                }
                unichar c = [uuidString characterAtIndex:i];
                [dashed appendFormat:@"%C", c];
            }
            NSUUID *reparsed = [[NSUUID alloc] initWithUUIDString:dashed];
            if (reparsed != nil) {
                self.id = reparsed;
                return self;
            }
        }

        // Fallback: zero UUID; if that ever fails (it shouldn't), use a random UUID
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
