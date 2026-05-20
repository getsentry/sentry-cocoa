#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// A single frame in a stack trace.
@interface SOCSentryFrame : NSObject

- (instancetype)init;

@property (nonatomic, copy, nullable) NSString *symbolAddress;
@property (nonatomic, copy, nullable) NSString *fileName;
@property (nonatomic, copy, nullable) NSString *function;

// `module` is a reserved C identifier; the Swift compiler exports the
// property under the `module_` ivar with `getter=module`/`setter=setModule:`
// attributes so ObjC consumers still spell it `module`.
@property (nonatomic, copy, nullable, getter=module, setter=setModule:) NSString *module_;

@property (nonatomic, copy, nullable) NSString *package;
@property (nonatomic, copy, nullable) NSString *imageAddress;
@property (nonatomic, copy, nullable) NSString *platform;
@property (nonatomic, copy, nullable) NSString *instructionAddress;
@property (nonatomic, strong, nullable) NSNumber *lineNumber;
@property (nonatomic, strong, nullable) NSNumber *columnNumber;
@property (nonatomic, copy, nullable) NSString *contextLine;
@property (nonatomic, strong, nullable) NSNumber *parentIndex;
@property (nonatomic, strong, nullable) NSNumber *sampleCount;
@property (nonatomic, copy, nullable) NSArray<NSString *> *preContext;
@property (nonatomic, copy, nullable) NSArray<NSString *> *postContext;
@property (nonatomic, strong, nullable) NSNumber *inApp;
@property (nonatomic, strong, nullable) NSNumber *stackStart;
@property (nonatomic, copy, nullable) NSDictionary<NSString *, id> *vars;

@end

NS_ASSUME_NONNULL_END
