#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Represents a single frame in a stacktrace.
 */
@interface SentryObjCFrame : NSObject

/// SymbolAddress of the frame.
@property (nonatomic, copy, nullable) NSString *symbolAddress;

/// Filename is used only for reporting JS frames.
@property (nonatomic, copy, nullable) NSString *fileName;

/// Function name of the frame.
@property (nonatomic, copy, nullable) NSString *function;

/// Module of the frame, mostly unused.
@property (nonatomic, copy, nullable) NSString *module;

/// Corresponding package.
@property (nonatomic, copy, nullable) NSString *package;

/// ImageAddress of the image related to the frame.
@property (nonatomic, copy, nullable) NSString *imageAddress;

/**
 * Set the platform for the individual frame, will use platform of the event.
 * Mostly used for React Native crashes.
 */
@property (nonatomic, copy, nullable) NSString *platform;

/// InstructionAddress of the frame in hex format.
@property (nonatomic, copy, nullable) NSString *instructionAddress;

/// Used for React Native, will be ignored for Cocoa frames.
@property (nonatomic, copy, nullable) NSNumber *lineNumber;

/// Used for React Native, will be ignored for Cocoa frames.
@property (nonatomic, copy, nullable) NSNumber *columnNumber;

/// Source code line at the error location. Mostly used for Godot errors.
@property (nonatomic, copy, nullable) NSString *contextLine;

/// Index of the parent frame used for flamegraphs.
@property (nonatomic, copy, nullable) NSNumber *parentIndex;

/// Number of samples recorded that contained this frame, used for flamegraphs.
@property (nonatomic, copy, nullable) NSNumber *sampleCount;

/// Source code lines before the error location (up to 5 lines). Mostly used for Godot errors.
@property (nonatomic, copy, nullable) NSArray<NSString *> *preContext;

/// Source code lines after the error location (up to 5 lines). Mostly used for Godot errors.
@property (nonatomic, copy, nullable) NSArray<NSString *> *postContext;

/// Determines if the frame is in-app or not.
@property (nonatomic, copy, nullable) NSNumber *inApp;

/// Determines if the frame is the base of an async continuation.
@property (nonatomic, copy, nullable) NSNumber *stackStart;

/// A mapping of variables which were available within this frame. Mostly used for Godot errors.
@property (nonatomic, copy, nullable) NSDictionary<NSString *, id> *vars;

- (instancetype)init;

@end

NS_ASSUME_NONNULL_END
