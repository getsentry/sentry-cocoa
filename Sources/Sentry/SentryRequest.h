#import "SentryDefines.h"
#import "SentrySerializable.h"

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(Request)
@interface SentryRequest : NSObject <SentrySerializable, NSCopying>

// TODO: data, env

/**
 * Optional: HTTP response body size.
 */
@property (atomic, copy) NSNumber *_Nullable bodySize;

/**
 * Optional: The cookie values.
 */
@property (atomic, copy) NSString *_Nullable cookies;

/**
* Optional: A dictionary of submitted headers.
*/
@property (nonatomic, strong) NSDictionary<NSString *, NSString *> *_Nullable headers;

/**
 * Optional: The fragment of the request URL.
 */
@property (atomic, copy) NSString *_Nullable fragment;

/**
 * Optional: HTTP request method.
 */
@property (atomic, copy) NSString *_Nullable method;

/**
 * Optional: The query string component of the URL.
 */
@property (atomic, copy) NSString *_Nullable queryString;

/**
 * Optional: The URL of the request if available.
 */
@property (atomic, copy) NSString *_Nullable url;

///**
// * Optional: HTTP status code.
// */
//@property (atomic, copy) NSNumber *_Nullable statusCode;

- (instancetype)init;

@end

NS_ASSUME_NONNULL_END
