#import "SentryEvent.h"
#import "SentryTracer.h"

NS_ASSUME_NONNULL_BEGIN

@class SentryTracer;
@protocol SentrySpanSerializable;

NS_SWIFT_NAME(Transaction)
@interface SentryTransaction : SentryEvent
SENTRY_NO_INIT

@property (nonatomic, strong) SentryTracer *trace;
@property (nonatomic, copy, nullable) NSArray<NSString *> *viewNames;
@property (nonatomic, strong) NSArray<id<SentrySpanSerializable>> *spans;

- (instancetype)initWithTrace:(SentryTracer *)trace
                     children:(NSArray<id<SentrySpanSerializable>> *)children;

@end

NS_ASSUME_NONNULL_END
