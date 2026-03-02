#import "SentryNetworkBody.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Represents captured HTTP request or response details.
 * Mirrors sentry-java ReplayNetworkRequestOrResponse class.
 */
@interface SentryReplayNetworkRequestOrResponse : NSObject

/** Content size in bytes (nullable) */
@property (nonatomic, strong, readonly, nullable) NSNumber *size;

/** Body content (nullable) */
@property (nonatomic, strong, readonly, nullable) SentryNetworkBody *body;

/** HTTP headers (non-null) */
@property (nonatomic, copy, readonly) NSDictionary<NSString *, NSString *> *headers;

- (instancetype)initWithSize:(nullable NSNumber *)size
                        body:(nullable SentryNetworkBody *)body
                     headers:(NSDictionary<NSString *, NSString *> *)headers
    NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

/** Serializes to dictionary for inclusion in breadcrumb data. */
- (NSDictionary *)serialize;

@end

NS_ASSUME_NONNULL_END