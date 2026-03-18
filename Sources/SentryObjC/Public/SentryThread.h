#import <Foundation/Foundation.h>

#import "SentryDefines.h"
#import "SentrySerializable.h"

@class SentryStacktrace;

NS_ASSUME_NONNULL_BEGIN

/**
 * Thread information for an event.
 *
 * Represents a thread's state at the time of an event, including its stack trace
 * and metadata about whether it crashed or was the current/main thread.
 *
 * @see SentryEvent
 */
@interface SentryThread : NSObject <SentrySerializable>

SENTRY_NO_INIT

/**
 * Unique identifier for this thread.
 */
@property (nullable, nonatomic, copy) NSNumber *threadId;

/**
 * Name of the thread, if available.
 *
 * Named threads (e.g., from @c pthread_setname_np) display better in Sentry.
 */
@property (nullable, nonatomic, copy) NSString *name;

/**
 * Stack trace for this thread.
 *
 * Contains the call stack at the time the event occurred.
 */
@property (nullable, nonatomic, strong) SentryStacktrace *stacktrace;

/**
 * Whether this thread crashed.
 *
 * @c YES for the crashing thread, @c NO for other threads.
 */
@property (nullable, nonatomic, copy) NSNumber *crashed;

/**
 * Whether this was the currently executing thread.
 *
 * @c YES for the thread that was running when the event occurred.
 */
@property (nullable, nonatomic, copy) NSNumber *current;

/**
 * Whether this is the main thread.
 *
 * @c YES for the main/UI thread.
 */
@property (nullable, nonatomic, copy) NSNumber *isMain;

/**
 * Creates thread information with a thread ID.
 *
 * @param threadId The thread identifier, or @c nil if unknown.
 * @return A new thread instance.
 */
- (instancetype)initWithThreadId:(nullable NSNumber *)threadId;

@end

NS_ASSUME_NONNULL_END
