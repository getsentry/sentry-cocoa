#import "SentryDefines.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * A class that periodically reads the size of the Documents & Data
 * folder, and stores it in `appDataSize`.
 * It only does this on iOS, as on macOS it would read the entire user's
 * home directory size, which is not helpful.
 */
@interface SentryAppDataSizeObserver : NSObject

// The size of Documents & Data. This gets updated periodically.
// A value of -1 means the size wasn't calculated (yet).
@property (nonatomic) long long appDataSize;

@end

NS_ASSUME_NONNULL_END
