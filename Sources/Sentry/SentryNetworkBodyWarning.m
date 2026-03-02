#import "SentryNetworkBodyWarning.h"

NSString *
SentryNetworkBodyWarningToString(SentryNetworkBodyWarning warning)
{
    switch (warning) {
    case SentryNetworkBodyWarningJsonTruncated:
        return @"JSON_TRUNCATED";
    case SentryNetworkBodyWarningTextTruncated:
        return @"TEXT_TRUNCATED";
    case SentryNetworkBodyWarningInvalidJson:
        return @"INVALID_JSON";
    case SentryNetworkBodyWarningBodyParseError:
        return @"BODY_PARSE_ERROR";
    }
}