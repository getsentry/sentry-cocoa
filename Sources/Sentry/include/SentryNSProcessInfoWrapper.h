#import "SentryDefines.h"

NS_ASSUME_NONNULL_BEGIN

@interface SentryNSProcessInfoWrapper : SENTRY_BASE_OBJECT

@property (nonatomic, readonly) NSString *processDirectoryPath;
@property (nullable, nonatomic, readonly) NSString *processPath;
@property (readonly) NSUInteger processorCount;

#if TEST
- (void)setProcessPath:(NSString *)path;
#endif

@end

NS_ASSUME_NONNULL_END
