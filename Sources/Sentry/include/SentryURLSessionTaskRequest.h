#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Reads the requests of a @c NSURLSessionTask without bridging them to Swift's @c URLRequest.
 *
 * Swift imports @c NSURLRequest as @c URLRequest. Bridging makes a mutable copy of the request,
 * including its protocol-property dictionary, without synchronizing with threads that write
 * protocol properties into the task's request. Releasing a copy taken during such a write crashes
 * in CoreFoundation. The return type is @c NSObject so that Swift keeps the request object, which
 * callers cast to @c NSURLRequest.
 */
@interface SentryURLSessionTaskRequest : NSObject

+ (nullable NSObject *)originalRequestOfTask:(NSURLSessionTask *)task
    NS_SWIFT_NAME(originalRequest(of:));

+ (nullable NSObject *)currentRequestOfTask:(NSURLSessionTask *)task
    NS_SWIFT_NAME(currentRequest(of:));

@end

NS_ASSUME_NONNULL_END
