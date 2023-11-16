#import "SentryDefines.h"

NS_ASSUME_NONNULL_BEGIN

@protocol SentryAutoSpanStarter <NSObject>

- (void)startSpan:(SentrySpanCallback)callback;

@end

NS_ASSUME_NONNULL_END
