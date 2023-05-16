#import "SentryBacktrace.hpp"
#import "SentryProfilingConditionals.h"
#import <Foundation/Foundation.h>

#if SENTRY_TARGET_PROFILING_SUPPORTED

NS_ASSUME_NONNULL_BEGIN

@class SentrySample;

@interface SentryProfilingMutableState : NSObject
@property (nonatomic, strong, readonly) NSMutableArray<SentrySample *> *samples;
@property (nonatomic, strong, readonly) NSMutableArray<NSArray<NSNumber *> *> *stacks;
@property (nonatomic, strong, readonly) NSMutableArray<NSDictionary<NSString *, id> *> *frames;
@property (nonatomic, strong, readonly)
    NSMutableDictionary<NSString *, NSMutableDictionary *> *threadMetadata;
@property (nonatomic, strong, readonly)
    NSMutableDictionary<NSString *, NSDictionary *> *queueMetadata;

/*
 * Maintain an index of unique frames to avoid duplicating large amounts of data. Every
 * unique frame is stored in an array, and every time a stack trace is captured for a
 * sample, the stack is stored as an array of integers indexing into the array of frames.
 * Stacks are thusly also stored as unique elements in their own index, an array of arrays
 * of frame indices, and each sample references a stack by index, to deduplicate common
 * stacks between samples, such as when the same deep function call runs across multiple
 * samples.
 *
 * E.g. if we have the following samples in the following function call stacks:
 *
 *              v sample1    v sample2               v sample3    v sample4
 * |-foo--------|------------|-----|    |-abc--------|------------|-----|
 *    |-bar-----|------------|--|          |-def-----|------------|--|
 *      |-baz---|------------|-|             |-ghi---|------------|-|
 *
 * Then we'd wind up with the following structures:
 *
 * frames: [
 *   { function: foo, instruction_addr: ... },
 *   { function: bar, instruction_addr: ... },
 *   { function: baz, instruction_addr: ... },
 *   { function: abc, instruction_addr: ... },
 *   { function: def, instruction_addr: ... },
 *   { function: ghi, instruction_addr: ... }
 * ]
 * stacks: [ [0, 1, 2], [3, 4, 5] ]
 * samples: [
 *   { stack_id: 0, ... },
 *   { stack_id: 0, ... },
 *   { stack_id: 1, ... },
 *   { stack_id: 1, ... }
 * ]
 */
@property (nonatomic, strong, readonly)
    NSMutableDictionary<NSString *, NSNumber *> *frameIndexLookup;
@property (nonatomic, strong, readonly)
    NSMutableDictionary<NSString *, NSNumber *> *stackIndexLookup;
@end

@interface SentryProfilingState : NSObject
// All functions are safe to call from multiple threads concurrently
- (void)mutate:(void (^)(SentryProfilingMutableState *))block;
- (void)appendBacktrace:(const sentry::profiling::Backtrace &)backtrace;
- (NSDictionary<NSString *, id> *)copyProfilingData;
@end

NS_ASSUME_NONNULL_END

#endif
