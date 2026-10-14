#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Wraps a request so Swift can read it without bridging it to a @c URLRequest.
 *
 * Swift bridges @c NSURLRequest to a @c URLRequest copy. Copying a task's request races with
 * threads that write protocol properties into it, and releasing a copy taken during such a write
 * crashes in CoreFoundation. Read the task's requests through this class instead.
 */
@interface SentryURLRequestWrapper : NSObject

+ (nullable instancetype)wrapperForOriginalRequestOfTask:(NSURLSessionTask *)task
    NS_SWIFT_NAME(init(originalRequestOf:));

+ (nullable instancetype)wrapperForCurrentRequestOfTask:(NSURLSessionTask *)task
    NS_SWIFT_NAME(init(currentRequestOf:));

- (instancetype)initWithRequest:(NSURLRequest *)request NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

/**
 * The wrapped request. Swift bridges it to a @c URLRequest copy, so only read it to hand the
 * request to user code.
 */
@property (nonatomic, readonly) NSURLRequest *request;

@property (nonatomic, readonly, nullable) NSURL *URL;
@property (nonatomic, readonly, nullable) NSString *HTTPMethod;
@property (nonatomic, readonly, nullable) NSData *HTTPBody;

// sentry-lint:disable avoid_all_header_fields
@property (nonatomic, readonly, nullable) NSDictionary<NSString *, NSString *> *allHTTPHeaderFields;
// sentry-lint:enable avoid_all_header_fields

- (nullable NSString *)valueForHTTPHeaderField:(NSString *)field;

@end

NS_ASSUME_NONNULL_END
