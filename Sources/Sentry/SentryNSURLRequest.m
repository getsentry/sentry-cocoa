#import "SentryNSURLRequest.h"
#import "SentryClient.h"
#import "SentryDsn.h"
#import "SentryError.h"
#import "SentryEvent.h"
#import "SentryHub.h"
#import "SentryLog.h"
#import "SentryMeta.h"
#import "SentryNSDataUtils.h"
#import "SentryOptions.h"
#import "SentrySDK+Private.h"
#import "SentrySerialization.h"
#import "SentrySwift.h"

NS_ASSUME_NONNULL_BEGIN

NSString *const SentryServerVersionString = @"7";
NSTimeInterval const SentryRequestTimeout = 15;

@implementation SentryNSURLRequest

- (_Nullable instancetype)initEnvelopeRequestWithDsn:(SentryDsn *)dsn
                                             andData:(NSData *)data
                                    didFailWithError:(NSError *_Nullable *_Nullable)error
{
    NSURL *apiURL = [dsn getEnvelopeEndpoint];
    NSString *authHeader = newAuthHeader(dsn.url);

    return [self initEnvelopeRequestWithURL:apiURL
                                    andData:data
                                 authHeader:authHeader
                           didFailWithError:error];
}

- (instancetype)initEnvelopeRequestWithURL:(NSURL *)url
                                   andData:(NSData *)data
                                authHeader:(nullable NSString *)authHeader
                          didFailWithError:(NSError *_Nullable *_Nullable)error
{
    self = [super initWithURL:url
                  cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
              timeoutInterval:SentryRequestTimeout];
    if (self) {
        self.HTTPMethod = @"POST";

        if (authHeader != nil) {
            [self setValue:authHeader forHTTPHeaderField:@"X-Sentry-Auth"];
        }
        [self setValue:@"application/x-sentry-envelope" forHTTPHeaderField:@"Content-Type"];
        [self setValue:[NSString
                           stringWithFormat:@"%@/%@", SentryMeta.sdkName, SentryMeta.versionString]
            forHTTPHeaderField:@"User-Agent"];
        [self setValue:@"gzip" forHTTPHeaderField:@"Content-Encoding"];
        self.HTTPBody = sentry_gzippedWithCompressionLevel(data, -1, error);

        SENTRY_LOG_DEBUG(@"Constructed request: %@", self);
    }

    return self;
}

static NSString *
newHeaderPart(NSString *key, id value)
{
    return [NSString stringWithFormat:@"%@=%@", key, value];
}

static NSString *
newAuthHeader(NSURL *url)
{
    NSMutableString *string = [NSMutableString stringWithString:@"Sentry "];
    [string appendFormat:@"%@,", newHeaderPart(@"sentry_version", SentryServerVersionString)];
    [string appendFormat:@"%@,",
        newHeaderPart(@"sentry_client",
            [NSString stringWithFormat:@"%@/%@", SentryMeta.sdkName, SentryMeta.versionString])];
    [string appendFormat:@"%@", newHeaderPart(@"sentry_key", url.user)];
    if (nil != url.password) {
        [string appendFormat:@",%@", newHeaderPart(@"sentry_secret", url.password)];
    }
    return string;
}

@end

NS_ASSUME_NONNULL_END
