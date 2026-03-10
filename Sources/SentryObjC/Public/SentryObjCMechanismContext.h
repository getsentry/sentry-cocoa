#import <Foundation/Foundation.h>

#import "SentryObjCSerializable.h"

@class SentryNSError;

NS_ASSUME_NONNULL_BEGIN

/**
 * Mechanism metadata with error codes from the runtime or OS.
 *
 * Provides low-level error details from signals, Mach exceptions, and NSError instances
 * that caused an exception. Used for crash report metadata.
 *
 * @see https://develop.sentry.dev/sdk/event-payloads/exception/#meta-information
 */
@interface SentryMechanismContext : NSObject <SentrySerializable>

/**
 * Creates a new mechanism context.
 *
 * @return A new instance.
 */
- (instancetype)init;

/// Signal metadata (signal number, code, address, etc.).
@property (nullable, nonatomic, strong) NSDictionary<NSString *, id> *signal;

/// Mach exception metadata (exception type, codes, etc.).
@property (nullable, nonatomic, strong) NSDictionary<NSString *, id> *machException;

/// Structured @c NSError information.
@property (nullable, nonatomic, strong) SentryNSError *error;

@end

NS_ASSUME_NONNULL_END
