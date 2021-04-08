#import "SentrySpanStatus.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentryPerformanceTracker : NSObject

- (NSMutableDictionary *)spansForThread;

- (NSMutableArray *)activeStackForThread;

- (NSString *)startSpanWithName:(NSString *)name;

- (NSString *)startSpanWithName:(NSString *)name operation:(nullable NSString *)operation;

- (void)pushActiveSpan:(NSString *)spanId;

- (void)popActiveSpan;

- (void)finishSpan:(NSString *)spanId;

- (void)finishSpan:(NSString *)spanId withStatus:(SentrySpanStatus)status;
@end

NS_ASSUME_NONNULL_END
