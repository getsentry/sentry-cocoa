#import "SentryPerformanceTracker.h"
#import "SentrySpan.h"
#import "SentrySpanId.h"
#import "SentryTracer.h"

NS_ASSUME_NONNULL_BEGIN

@interface
SentryPerformanceTracker (Testing) <SentryTracerDelegate>

- (void)clear;

@end

NS_ASSUME_NONNULL_END
