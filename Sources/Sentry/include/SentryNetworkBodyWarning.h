#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Warning codes for network body capture issues.
 * Mirrors sentry-java NetworkBody.NetworkBodyWarning enum.
 */
typedef NS_ENUM(NSInteger, SentryNetworkBodyWarning) {
    /** JSON body was truncated mid-parse */
    SentryNetworkBodyWarningJsonTruncated,

    /** Text body was truncated */
    SentryNetworkBodyWarningTextTruncated,

    /** JSON parsing failed - body is malformed */
    SentryNetworkBodyWarningInvalidJson,

    /** Generic body parse error */
    SentryNetworkBodyWarningBodyParseError
};

/**
 * Converts a warning enum value to its string representation for serialization.
 */
FOUNDATION_EXPORT NSString *_Nonnull SentryNetworkBodyWarningToString(
    SentryNetworkBodyWarning warning);

NS_ASSUME_NONNULL_END