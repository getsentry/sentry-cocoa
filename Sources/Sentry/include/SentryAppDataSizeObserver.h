#import "SentryDefines.h"

NS_ASSUME_NONNULL_BEGIN

@interface SentryAppDataSizeObserver : NSObject

// The size of Documents & Data. This gets updated periodically.
// A value of -1 means the size wasn't calculated (yet).
@property (nonatomic) long long appDataSize;

@end

NS_ASSUME_NONNULL_END
