#import <Foundation/Foundation.h>

#import "SentryObjCDefines.h"
#import "SentryObjCSerializable.h"

@class SentryMechanismContext;

NS_ASSUME_NONNULL_BEGIN

/**
 * Error mechanism describing how the error was produced.
 *
 * Provides context about how an exception was captured, including whether it was
 * handled, what system generated it, and any relevant debugging information.
 *
 * @see SentryException
 */
@interface SentryMechanism : NSObject <SentrySerializable>

SENTRY_NO_INIT

/**
 * Mechanism type identifier.
 *
 * Examples: "generic", "onerror", "promise", "signal".
 */
@property (nonatomic, copy) NSString *type;

/**
 * Human-readable description of the mechanism.
 */
@property (nonatomic, copy, nullable) NSString *desc;

/**
 * Arbitrary data attached to the mechanism.
 *
 * May contain signal numbers, error codes, or other mechanism-specific data.
 */
@property (nonatomic, strong, nullable) NSDictionary<NSString *, id> *data;

/**
 * Whether the exception was handled by application code.
 *
 * @c @YES if caught and handled, @c @NO if unhandled/fatal.
 */
@property (nonatomic, copy, nullable) NSNumber *handled;

/**
 * Whether the exception was generated synthetically.
 *
 * @c @YES for exceptions created by instrumentation rather than thrown naturally.
 */
@property (nonatomic, copy, nullable) NSNumber *synthetic;

/**
 * URL to documentation about this mechanism.
 */
@property (nonatomic, copy, nullable) NSString *helpLink;

/**
 * Additional metadata about the mechanism.
 */
@property (nullable, nonatomic, strong) SentryMechanismContext *meta;

/**
 * Creates a mechanism with the specified type.
 *
 * @param type The mechanism type identifier.
 * @return A new mechanism instance.
 */
- (instancetype)initWithType:(NSString *)type;

@end

NS_ASSUME_NONNULL_END
