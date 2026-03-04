#import <Foundation/Foundation.h>

#import "SentryObjCSerializable.h"

@class SentryNSError;

NS_ASSUME_NONNULL_BEGIN

/**
 * Mechanism metadata with error codes from the runtime or OS.
 *
 * @see https://develop.sentry.dev/sdk/event-payloads/exception/#meta-information
 */
@interface SentryMechanismContext : NSObject <SentrySerializable>

- (instancetype)init;

@property (nullable, nonatomic, strong) NSDictionary<NSString *, id> *signal;
@property (nullable, nonatomic, strong) NSDictionary<NSString *, id> *machException;
@property (nullable, nonatomic, strong) SentryNSError *error;

@end

NS_ASSUME_NONNULL_END
