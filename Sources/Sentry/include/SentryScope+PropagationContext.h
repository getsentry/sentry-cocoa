#import "SentryScope.h"

@class SentryId;

NS_ASSUME_NONNULL_BEGIN

@interface SentryScope ()

@property (nonatomic, readonly) SentryId *propagationContextTraceId;

@end

NS_ASSUME_NONNULL_END
