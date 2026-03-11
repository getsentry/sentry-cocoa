#import <Foundation/Foundation.h>

#import "SentryObjCSerializable.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * A single frame in a stack trace.
 *
 * Represents one function call in a call stack, including location information,
 * source code context, and debugging metadata.
 *
 * @see SentryStacktrace
 */
@interface SentryFrame : NSObject <SentrySerializable>

/**
 * Address of the symbol for this frame.
 */
@property (nonatomic, copy) NSString *symbolAddress;

/**
 * Source file name where this frame's code is located.
 */
@property (nonatomic, copy) NSString *fileName;

/**
 * Function or method name for this frame.
 */
@property (nonatomic, copy) NSString *function;

/**
 * Module (framework or library) containing this frame's code.
 */
@property (nonatomic, copy) NSString *module;

/**
 * Package or bundle identifier.
 */
@property (nonatomic, copy) NSString *package;

/**
 * Base address of the image (binary) containing this frame.
 */
@property (nonatomic, copy) NSString *imageAddress;

/**
 * Platform identifier for this frame.
 */
@property (nonatomic, copy) NSString *platform;

/**
 * Memory address of the instruction for this frame.
 */
@property (nonatomic, copy) NSString *instructionAddress;

/**
 * Line number in the source file.
 */
@property (nonatomic, copy) NSNumber *lineNumber;

/**
 * Column number in the source line.
 */
@property (nonatomic, copy) NSNumber *columnNumber;

/**
 * Source code line at this frame's location.
 */
@property (nonatomic, copy) NSString *contextLine;

/**
 * Source code lines before the current line (for context).
 */
@property (nonatomic, copy) NSArray<NSString *> *preContext;

/**
 * Source code lines after the current line (for context).
 */
@property (nonatomic, copy) NSArray<NSString *> *postContext;

/**
 * Whether this frame is from application code.
 *
 * @c YES for app code, @c NO for framework/system code.
 */
@property (nonatomic, copy) NSNumber *inApp;

/**
 * Whether this frame marks the start of the stack.
 */
@property (nonatomic, copy) NSNumber *stackStart;

/**
 * Local variables visible at this frame.
 */
@property (nonatomic, copy) NSDictionary<NSString *, id> *vars;

/**
 * Creates a new frame with default values.
 *
 * @return A new frame instance.
 */
- (instancetype)init;

@end

NS_ASSUME_NONNULL_END
