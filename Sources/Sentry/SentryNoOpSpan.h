#import "SentryDefines.h"
#import "SentrySerializable.h"
#import "SentrySpan.h"
#import "SentrySpanContext.h"
#import "SentrySpanProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@interface SentryNoOpSpan : SentrySpan
SENTRY_NO_INIT

+ (instancetype)shared;

@end

NS_ASSUME_NONNULL_END
