#import <Foundation/Foundation.h>

@class SentryObjCFrame;

NS_ASSUME_NONNULL_BEGIN

/**
 * Represents a stacktrace containing a list of frames and register values.
 */
@interface SentryObjCStacktrace : NSObject

/**
 * Array of all frames in the stacktrace.
 */
@property (nonatomic, strong) NSArray<SentryObjCFrame *> *frames;

/**
 * Registers of the thread for additional information used on the server.
 */
@property (nonatomic, strong) NSDictionary<NSString *, NSString *> *registers;

/**
 * Indicates that this stack trace is a snapshot triggered by an external signal.
 */
@property (nonatomic, copy, nullable) NSNumber *snapshot;

/**
 * Initialize a @c SentryObjCStacktrace with frames and registers.
 * @param frames Array of stack frames.
 * @param registers Dictionary of register names to values.
 */
- (instancetype)initWithFrames:(NSArray<SentryObjCFrame *> *)frames
                     registers:(NSDictionary<NSString *, NSString *> *)registers;

@end

NS_ASSUME_NONNULL_END
