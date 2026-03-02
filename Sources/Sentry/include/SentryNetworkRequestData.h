#import "SentryDefines.h"
#import "SentryReplayNetworkRequestOrResponse.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Key used to store network details in breadcrumb data dictionary.
 */
SENTRY_EXTERN NSString *const SentryReplayNetworkDetailsKey;

/**
 * Main container for network request/response tracking.
 * Mirrors sentry-java NetworkRequestData class.
 */
@interface SentryNetworkRequestData : NSObject

/** HTTP method (nullable) */
@property (nonatomic, copy, readonly, nullable) NSString *method;

/** HTTP status code (nullable) */
@property (nonatomic, strong, readonly, nullable) NSNumber *statusCode;

/** Request body size in bytes (nullable) */
@property (nonatomic, strong, readonly, nullable) NSNumber *requestBodySize;

/** Response body size in bytes (nullable) */
@property (nonatomic, strong, readonly, nullable) NSNumber *responseBodySize;

/** Request details (nullable) */
@property (nonatomic, strong, readonly, nullable) SentryReplayNetworkRequestOrResponse *request;

/** Response details (nullable) */
@property (nonatomic, strong, readonly, nullable) SentryReplayNetworkRequestOrResponse *response;

- (instancetype)initWithMethod:(nullable NSString *)method NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

/** Sets request details and updates requestBodySize */
- (void)setRequestDetails:(SentryReplayNetworkRequestOrResponse *)requestData;

/** Sets response details, statusCode, and updates responseBodySize */
- (void)setResponseDetails:(NSInteger)statusCode
              responseData:(SentryReplayNetworkRequestOrResponse *)responseData;

/** Serializes to dictionary for inclusion in breadcrumb data. */
- (NSDictionary *)serialize;

@end

NS_ASSUME_NONNULL_END