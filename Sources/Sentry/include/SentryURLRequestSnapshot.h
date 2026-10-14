#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * A task's request, read once in Objective-C.
 *
 * Swift bridges @c NSURLRequest to a @c URLRequest copy. Copying a task's request races with
 * threads that write protocol properties into it, and releasing a copy taken during such a write
 * crashes in CoreFoundation. Read the task's requests through this class instead.
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
@property (nonatomic, readonly, nullable) NSData *HTTPBody;

// sentry-lint:disable avoid_all_header_fields
@property (nonatomic, readonly, nullable) NSDictionary<NSString *, NSString *> *allHTTPHeaderFields;
// sentry-lint:enable avoid_all_header_fields

- (nullable NSString *)valueForHTTPHeaderField:(NSString *)field;

@end

NS_ASSUME_NONNULL_END
