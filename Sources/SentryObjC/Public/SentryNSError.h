#import <Foundation/Foundation.h>

#import "SentryDefines.h"
#import "SentrySerializable.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Serializable representation of an @c NSError.
 *
 * Captures the essential error information (domain and code) for event payloads.
 * Used in mechanism metadata to provide structured error details.
 *
 * @see SentryMechanismContext
 */
@interface SentryNSError : NSObject <SentrySerializable>

SENTRY_NO_INIT

/// The error domain (e.g., @c NSCocoaErrorDomain, @c SentryErrorDomain).
@property (nonatomic, copy) NSString *domain;

/// The error code within the domain.
@property (nonatomic, assign) NSInteger code;

/**
 * Creates an error representation with domain and code.
 *
 * @param domain The error domain.
 * @param code The error code.
 * @return A new instance.
 */
- (instancetype)initWithDomain:(NSString *)domain code:(NSInteger)code;

@end

NS_ASSUME_NONNULL_END
