#import "SentryException.h"
#import "SentryMechanism.h"
#import "SentryStacktrace.h"
#import "SentryThread.h"

NS_ASSUME_NONNULL_BEGIN

@implementation SentryException

- (instancetype)initWithValue:(NSString *_Nullable)value type:(NSString *_Nullable)type
{
    self = [super init];
    if (self) {
        NSAssert(value != nil || type != nil,
            @"SentryException requires at least one of value or type to be non-nil");
        self.value = value;
        self.type = type;
    }
    return self;
}

- (NSDictionary<NSString *, id> *)serialize
{
    NSMutableDictionary *serializedData = [[NSMutableDictionary alloc] init];

    [serializedData setValue:self.value forKey:@"value"];
    [serializedData setValue:self.type forKey:@"type"];
    [serializedData setValue:[self.mechanism serialize] forKey:@"mechanism"];
    [serializedData setValue:self.module forKey:@"module"];
    [serializedData setValue:self.threadId forKey:@"thread_id"];
    [serializedData setValue:[self.stacktrace serialize] forKey:@"stacktrace"];

    return serializedData;
}

@end

NS_ASSUME_NONNULL_END
