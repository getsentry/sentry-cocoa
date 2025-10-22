#import "SentryDefines.h"
#import "SentrySpan.h"
#import "SentrySpanContext.h"
#import "SentrySpanProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@interface SentryNoOpSpan : SentrySpan
SENTRY_NO_INIT

+ (instancetype)shared;

@property (nonatomic, readonly) SentrySpanContext *context;
@property (readonly) BOOL isFinished;
@property (nullable, readonly) NSDictionary<NSString *, id> *data;
@property (readonly) NSDictionary<NSString *, NSString *> *tags;

@end

NS_ASSUME_NONNULL_END
