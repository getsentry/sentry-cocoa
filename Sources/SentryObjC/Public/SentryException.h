#import <Foundation/Foundation.h>

#import "SentryObjCDefines.h"
#import "SentryObjCSerializable.h"

@class SentryMechanism;
@class SentryStacktrace;

NS_ASSUME_NONNULL_BEGIN

/**
 * Exception information for an event.
 *
 * Represents an exception or error that occurred. Events can contain multiple
 * exceptions for chained or nested errors.
 *
 * @see SentryEvent
 */
@interface SentryException : NSObject <SentrySerializable>

SENTRY_NO_INIT

/**
 * The exception value (e.g., error message or description).
 */
@property (nonatomic, copy) NSString *value;

/**
 * The exception type (e.g., "NSInvalidArgumentException", "NullPointerException").
 */
@property (nonatomic, copy) NSString *type;

/**
 * Mechanism describing how the exception was captured.
 */
@property (nonatomic, strong) SentryMechanism *mechanism;

/**
 * Module or package where the exception originated.
 */
@property (nonatomic, copy) NSString *module;

/**
 * ID of the thread where the exception occurred.
 */
@property (nonatomic, copy) NSNumber *threadId;

/**
 * Stack trace associated with this exception.
 */
@property (nonatomic, strong) SentryStacktrace *stacktrace;

/**
 * Creates an exception with the specified value and type.
 *
 * @param value The exception message or description.
 * @param type The exception type name.
 * @return A new exception instance.
 */
- (instancetype)initWithValue:(NSString *)value type:(NSString *)type;

@end

NS_ASSUME_NONNULL_END
