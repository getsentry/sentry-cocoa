#import "SentryDefines.h"

NS_ASSUME_NONNULL_BEGIN

@interface SentryNSURLSessionTaskSearch : SENTRY_BASE_OBJECT

+ (NSArray<Class> *)urlSessionTaskClassesToTrack;

@end

NS_ASSUME_NONNULL_END
