#import <Foundation/Foundation.h>
#if !__has_include(<SentryObjC/SentryObjCDefines.h>)
#    import "SentryObjCDefines.h"
#else
#    import <SentryObjC/SentryObjCDefines.h>
#endif

@class SentryObjCMechanism;
@class SentryObjCStacktrace;

NS_ASSUME_NONNULL_BEGIN

/**
 * Represents a single exception in a Sentry event.
 */
@interface SentryObjCException : NSObject
SENTRY_NO_INIT

/// The name of the exception.
@property (nonatomic, copy, nullable) NSString *value;

/// Type of the exception.
@property (nonatomic, copy, nullable) NSString *type;

/// Additional information about the exception.
@property (nonatomic, strong, nullable) SentryObjCMechanism *mechanism;

/// Can be set to define the module.
@property (nonatomic, copy, nullable) NSString *module;

/// An optional value which refers to a thread in the event's threads.
@property (nonatomic, copy, nullable) NSNumber *threadId;

/// Stacktrace containing frames of this exception.
@property (nonatomic, strong, nullable) SentryObjCStacktrace *stacktrace;

/**
 * Initialize a @c SentryObjCException with value and type.
 * @param value Nullable string describing the exception.
 * @param type Nullable string with the type of the exception.
 * @note At least one of value or type must be non-nil.
 */
- (instancetype)initWithValue:(nullable NSString *)value type:(nullable NSString *)type;

@end

NS_ASSUME_NONNULL_END
