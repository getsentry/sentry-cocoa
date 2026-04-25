#import <Foundation/Foundation.h>

#import "SentryDefines.h"
#import "SentrySerializable.h"

@class SentryFrame;

NS_ASSUME_NONNULL_BEGIN

/**
 * Stack trace containing frames.
 *
 * Represents a call stack at a specific point in execution, typically when
 * an error or exception occurred. Contains ordered frames from the call site
 * up through the call chain.
 *
 * @see SentryEvent
 * @see SentryException
 */
@interface SentryStacktrace : NSObject <SentrySerializable>

SENTRY_NO_INIT

/**
 * Array of stack frames, ordered from outermost (top of stack) to innermost (call site).
 */
@property (nonatomic, strong) NSArray<SentryFrame *> *frames;

/**
 * CPU register values at the time the stack trace was captured.
 *
 * Keys are register names (e.g., "pc", "sp", "lr"), values are hex addresses.
 */
@property (nonatomic, strong) NSDictionary<NSString *, NSString *> *registers;

/**
 * Whether this is a snapshot of the stack at a specific point in time.
 *
 * Used to distinguish between crash stacks and periodic snapshots.
 */
@property (nonatomic, copy, nullable) NSNumber *snapshot;

/**
 * Creates a stack trace with frames and register values.
 *
 * @param frames Array of stack frames.
 * @param registers CPU register values.
 * @return A new stack trace instance.
 */
- (instancetype)initWithFrames:(NSArray<SentryFrame *> *)frames
                     registers:(NSDictionary<NSString *, NSString *> *)registers;

/**
 * Removes duplicate frames that may occur from inlining or recursion.
 *
 * @warning Internal method. Called automatically by the SDK.
 */
- (void)fixDuplicateFrames;

@end

NS_ASSUME_NONNULL_END
