#import "SentryDefines.h"
#import "SentrySerializable.h"

NS_ASSUME_NONNULL_BEGIN

@class SentryStacktrace;

NS_SWIFT_NAME(Thread)
@interface SentryThread : NSObject <SentrySerializable>
SENTRY_NO_INIT

/**
 * Number of the thread
 */
@property (nonatomic, copy) NSNumber *threadId;

/**
 * Name (if available) of the thread
 */
@property (nonatomic, copy) NSString *_Nullable name;

/**
 * SentryStacktrace of the SentryThread
 */
@property (nonatomic, strong) SentryStacktrace *_Nullable stacktrace;

/**
 * Did this thread crash?
 */
@property (nonatomic, copy) NSNumber *_Nullable crashed;

/**
 * Was it the current thread.
 */
@property (nonatomic, copy) NSNumber *_Nullable current;

/**
 * The thread from which this SentryThread extracted its information
 */
@property (nonatomic) uintptr_t thread;

/**
 * Initializes a SentryThread with its id
 * @param threadId NSNumber
 * @return SentryThread
 */
- (instancetype)initWithThreadId:(NSNumber *)threadId;

@end

NS_ASSUME_NONNULL_END
