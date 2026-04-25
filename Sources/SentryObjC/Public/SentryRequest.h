#import <Foundation/Foundation.h>

#import "SentrySerializable.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * HTTP request information for an event.
 *
 * Captures details about an HTTP request that was being processed when an
 * error occurred. Useful for web applications and API servers.
 *
 * @see SentryEvent
 */
@interface SentryRequest : NSObject <SentrySerializable>

/**
 * Size of the request body in bytes.
 */
@property (nonatomic, copy, nullable) NSNumber *bodySize;

/**
 * Cookies sent with the request.
 *
 * @note Only included when @c sendDefaultPii is @c YES.
 */
@property (nonatomic, copy, nullable) NSString *cookies;

/**
 * HTTP headers from the request.
 *
 * @note Sensitive headers are automatically filtered.
 */
@property (nonatomic, strong, nullable) NSDictionary<NSString *, NSString *> *headers;

/**
 * URL fragment (the part after #).
 */
@property (nonatomic, copy, nullable) NSString *fragment;

/**
 * HTTP method (GET, POST, etc.).
 */
@property (nonatomic, copy, nullable) NSString *method;

/**
 * Query string (the part after ?).
 */
@property (nonatomic, copy, nullable) NSString *queryString;

/**
 * Full request URL.
 */
@property (nonatomic, copy, nullable) NSString *url;

/**
 * Creates a new request instance.
 *
 * @return A new request instance.
 */
- (instancetype)init;

@end

NS_ASSUME_NONNULL_END
