#import "TestSentrySpan.h"
#import "SentrySpanProtocol.h"
#import "SentryTracer.h"

@implementation TestSentrySpan

- (instancetype)init
{
    return self;
}

- (id<SentrySpan>)startChildWithOperation:(NSString *)operation description:(NSString *)description
{
    return nil;
}

- (id<SentrySpan>)startChildWithOperation:(nonnull NSString *)operation
{
    return nil;
}

- (SentryTraceHeader *)toTraceHeader
{
    return nil;
}

- (NSDictionary<NSString *, id> *)serialize
{
    return nil;
}

- (void)finish
{
}

- (void)finishWithStatus:(SentrySpanStatus)status
{
}

- (void)removeDataForKey:(nonnull NSString *)key
{
}

- (void)removeTagForKey:(nonnull NSString *)key
{
}

- (void)setDataValue:(nullable id)value forKey:(nonnull NSString *)key
{
}

- (void)setExtraValue:(nullable id)value forKey:(nonnull NSString *)key
{
}

- (void)setTagValue:(nonnull NSString *)value forKey:(nonnull NSString *)key
{
}

- (void)setMeasurement:(nonnull NSString *)name value:(nonnull NSNumber *)value
{
}

- (void)setMeasurement:(NSString *)name value:(NSNumber *)value unit:(SentryMeasurementUnit *)unit
{
}

@end
