#import <Foundation/Foundation.h>

@class SOCSentryMechanism;
@class SOCSentryStacktrace;

NS_ASSUME_NONNULL_BEGIN

/// A captured exception with its stacktrace and mechanism metadata.
@interface SOCSentryException : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithValue:(nullable NSString *)value type:(nullable NSString *)type;

@property (nonatomic, copy, nullable) NSString *value;
@property (nonatomic, copy, nullable) NSString *type;
@property (nonatomic, strong, nullable) SOCSentryMechanism *mechanism;

// `module` is a reserved C identifier; the Swift compiler exports the
// property under the `module_` ivar with `getter=module`/`setter=setModule:`
// attributes so ObjC consumers still spell it `module`.
@property (nonatomic, copy, nullable, getter=module, setter=setModule:) NSString *module_;

@property (nonatomic, strong, nullable) NSNumber *threadId;
@property (nonatomic, strong, nullable) SOCSentryStacktrace *stacktrace;

@end

NS_ASSUME_NONNULL_END
