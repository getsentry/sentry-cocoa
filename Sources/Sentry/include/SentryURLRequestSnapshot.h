#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * The values of a @c NSURLSessionTask request that the SDK reads, taken once from the request.
 *
 * Swift imports @c NSURLRequest as @c URLRequest. Bridging makes a mutable copy of the request,
 * including its protocol-property dictionary, without synchronizing with threads that write
 * protocol properties into the task's request. Releasing a copy taken during such a write crashes
 * in CoreFoundation. Reading the values here keeps the request out of Swift.
 *
 * A task's @c originalRequest and @c currentRequest can change while the task runs, so each
 * snapshot reads its request once and keeps all values from that same request.
 */
@interface SentryURLRequestSnapshot : NSObject

+ (nullable instancetype)snapshotOfOriginalRequestOfTask:(NSURLSessionTask *)task
    NS_SWIFT_NAME(init(originalRequestOf:));

+ (nullable instancetype)snapshotOfCurrentRequestOfTask:(NSURLSessionTask *)task
    NS_SWIFT_NAME(init(currentRequestOf:));

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@property (nonatomic, readonly, nullable) NSURL *URL;
@property (nonatomic, readonly, nullable) NSString *HTTPMethod;
// For passing all headers on. Look up single headers with -valueForHTTPHeaderField:.
// sentry-lint:disable avoid_all_header_fields
@property (nonatomic, readonly, nullable) NSDictionary<NSString *, NSString *> *allHTTPHeaderFields;
// sentry-lint:enable avoid_all_header_fields
@property (nonatomic, readonly, nullable) NSData *HTTPBody;

/**
 * Returns the value of the header field of the request, matching its name case-insensitively.
 */
- (nullable NSString *)valueForHTTPHeaderField:(NSString *)field;

/**
 * Returns the request. Swift bridges it to a @c URLRequest copy, so only read it to hand the
 * request to user code, such as the hint of a @c beforeSend or @c beforeBreadcrumb callback.
 */
@property (nonatomic, readonly) NSURLRequest *requestCopy;

@end

NS_ASSUME_NONNULL_END
