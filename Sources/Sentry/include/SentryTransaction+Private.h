#import "SentryTransaction.h"

NS_ASSUME_NONNULL_BEGIN

@class SentryTracer;

@interface SentryTransaction ()

@property (nonatomic, strong) SentryTracer *trace;
@property (nonatomic, copy, nullable) NSArray<NSString *> *viewNames;

- (instancetype)initWithTrace:(SentryTracer *)trace children:(NSArray<id<SentrySpan>> *)children;

@end

NS_ASSUME_NONNULL_END
