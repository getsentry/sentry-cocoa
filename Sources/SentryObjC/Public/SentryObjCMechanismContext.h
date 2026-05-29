#import <Foundation/Foundation.h>

@class SentryObjCNSError;

NS_ASSUME_NONNULL_BEGIN

/**
 * The mechanism metadata usually carries error codes reported by the runtime or operating system,
 * along with a platform-dependent interpretation of these codes.
 * @see https://develop.sentry.dev/sdk/event-payloads/exception/#meta-information.
 */
@interface SentryObjCMechanismContext : NSObject

/**
 * Information on the POSIX signal. On Apple systems, signals also carry a code in addition to the
 * signal number describing the signal in more detail. On Linux, this code does not exist.
 */
@property (nonatomic, strong, nullable) NSDictionary<NSString *, id> *signal;

/**
 * A Mach Exception on Apple systems comprising a code triple and optional descriptions.
 */
@property (nonatomic, strong, nullable) NSDictionary<NSString *, id> *machException;

/**
 * Sentry uses the @c NSError's domain and code for grouping. Only domain and code are serialized.
 */
@property (nonatomic, strong, nullable) SentryObjCNSError *error;

- (instancetype)init;

@end

NS_ASSUME_NONNULL_END
