#import "SentryPerformanceTracker.h"
#import "SentrySpan.h"
#import "SentrySpanId.h"

NS_ASSUME_NONNULL_BEGIN

@interface
SentryPerformanceTracker (Testing) <SentryTracerDelegate>

@property (nonatomic, strong) NSMutableDictionary<SentrySpanId *, id<SentrySpan>> *spans;
@property (nonatomic, strong) NSMutableArray<id<SentrySpan>> *activeSpanStack;

@end

NS_ASSUME_NONNULL_END
