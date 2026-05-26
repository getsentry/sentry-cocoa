#import <Foundation/Foundation.h>

@class SentryObjCStacktrace;

NS_ASSUME_NONNULL_BEGIN

/**
 * Represents a thread of the event.
 */
@interface SentryObjCThread : NSObject

/**
 * Number of the thread.
 *
 * Can be nil for threads in recrash reports where the thread index information is not available.
 */
@property (nonatomic, copy, nullable) NSNumber *threadId;

/**
 * Name (if available) of the thread.
 */
@property (nonatomic, copy, nullable) NSString *name;

/**
 * Stacktrace of the thread.
 */
@property (nonatomic, strong, nullable) SentryObjCStacktrace *stacktrace;

/**
 * Did this thread crash?
 */
@property (nonatomic, copy, nullable) NSNumber *crashed;

/**
 * Was it the current thread.
 */
@property (nonatomic, copy, nullable) NSNumber *current;

/**
 * Was it the main thread?
 */
@property (nonatomic, copy, nullable) NSNumber *isMain;

/**
 * Initializes a @c SentryObjCThread with its id.
 * @param threadId NSNumber or nil if thread index is not available (e.g., recrash reports).
 */
- (instancetype)initWithThreadId:(nullable NSNumber *)threadId;

@end

NS_ASSUME_NONNULL_END
