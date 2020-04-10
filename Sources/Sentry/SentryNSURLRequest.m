#import "SentryDsn.h"
#import "SentryNSURLRequest.h"
#import "SentryClient.h"
#import "SentryEvent.h"
#import "SentryError.h"
#import "SentryLog.h"
#import "NSData+SentryCompression.h"
#import "SentrySDK.h"
#import "SentryMeta.h"
#import "SentrySerialization.h"

NS_ASSUME_NONNULL_BEGIN

NSString *const SentryServerVersionString = @"7";
NSTimeInterval const SentryRequestTimeout = 15;

@interface SentryNSURLRequest ()

@property(nonatomic, strong) SentryDsn *dsn;

@end

@implementation SentryNSURLRequest

- (_Nullable instancetype)initStoreRequestWithDsn:(SentryDsn *)dsn
                                         andEvent:(SentryEvent *)event
                                 didFailWithError:(NSError *_Nullable *_Nullable)error {
    NSData *jsonData;
    if (nil != event.json) {
        // If we have event.json, this has been set from JS and should be sent directly
        jsonData = event.json;
        [SentryLog logWithMessage:@"Using event->json attribute instead of serializing event" andLevel:kSentryLogLevelVerbose];
    } else {
        NSDictionary *serialized = [event serialize];
        jsonData = [SentrySerialization dataWithJSONObject:serialized
                                                   options:[SentrySDK.currentHub getClient].options.logLevel == kSentryLogLevelVerbose
                                                           ? NSJSONWritingPrettyPrinted : 0
                                                     error:error];
        if (nil == jsonData) {
            if (error) {
                // TODO: We're possibly overriding an error set by the actual code that failed ^
                *error = NSErrorFromSentryError(kSentryErrorJsonConversionError, @"Event cannot be converted to JSON");
            }
            return nil;
        }
    }
    
    if ([SentrySDK.currentHub getClient].options.logLevel == kSentryLogLevelVerbose) {
        [SentryLog logWithMessage:@"Sending JSON -------------------------------" andLevel:kSentryLogLevelVerbose];
        [SentryLog logWithMessage:[NSString stringWithFormat:@"%@", [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding]] andLevel:kSentryLogLevelVerbose];
        [SentryLog logWithMessage:@"--------------------------------------------" andLevel:kSentryLogLevelVerbose];
    }
    return [self initStoreRequestWithDsn:dsn andData:jsonData didFailWithError:error];
}

- (_Nullable instancetype)initStoreRequestWithDsn:(SentryDsn *)dsn
                                          andData:(NSData *)data
                                 didFailWithError:(NSError *_Nullable *_Nullable)error {
    NSURL *apiURL = [self.class getStoreUrlFromDsn:dsn];
    self = [super initWithURL:apiURL cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:SentryRequestTimeout];
    if (self) {
        NSString *authHeader = newAuthHeader(dsn.url);

        self.HTTPMethod = @"POST";
        [self setValue:authHeader forHTTPHeaderField:@"X-Sentry-Auth"];
        [self setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        [self setValue:@"sentry-cocoa" forHTTPHeaderField:@"User-Agent"];
        [self setValue:@"gzip" forHTTPHeaderField:@"Content-Encoding"];
        self.HTTPBody = [data sentry_gzippedWithCompressionLevel:-1 error:error];
    }
    return self;
}

// TODO: Get refactored out to be a single init method
- (_Nullable instancetype)initEnvelopeRequestWithDsn:(SentryDsn *)dsn
                                             andData:(NSData *)data
                                 didFailWithError:(NSError *_Nullable *_Nullable)error {
    NSURL *apiURL = [self.class getStoreUrlFromDsn:dsn];
    self = [super initWithURL:apiURL cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:SentryRequestTimeout];
    if (self) {
        NSString *authHeader = newAuthHeader(dsn.url);

        self.HTTPMethod = @"POST";
        [self setValue:authHeader forHTTPHeaderField:@"X-Sentry-Auth"];
        [self setValue:@"application/x-sentry-envelope" forHTTPHeaderField:@"Content-Type"];
        [self setValue:@"sentry-cocoa" forHTTPHeaderField:@"User-Agent"];
        [self setValue:@"gzip" forHTTPHeaderField:@"Content-Encoding"];
        self.HTTPBody = [data sentry_gzippedWithCompressionLevel:-1 error:error];
    }
    
    if ([SentrySDK.currentHub getClient].options.logLevel == kSentryLogLevelVerbose) {
        [SentryLog logWithMessage:[NSString stringWithFormat:@"Envelope request with data: %@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]] andLevel:kSentryLogLevelVerbose];
    }
    return self;
}

+ (NSURL *)getStoreUrlFromDsn:(SentryDsn *)dsn {
    NSURL *url = dsn.url;
    NSString *projectId = url.lastPathComponent;
    NSMutableArray *paths = [url.pathComponents mutableCopy];
    // [0] = /
    // [1] = projectId
    // If there are more than two, that means someone wants to have an additional path
    // ref: https://github.com/getsentry/sentry-cocoa/issues/236
    NSString *path = @"";
    if ([paths count] > 2) {
        [paths removeObjectAtIndex:0]; // We remove the leading /
        [paths removeLastObject]; // We remove projectId since we add it later
        path = [NSString stringWithFormat:@"/%@", [paths componentsJoinedByString:@"/"]]; // We put together the path
    }
    NSURLComponents *components = [NSURLComponents new];
    components.scheme = url.scheme;
    components.host = url.host;
    components.port = url.port;
    components.path = [NSString stringWithFormat:@"%@/api/%@/store/", path, projectId];
    return components.URL;
}

static NSString *newHeaderPart(NSString *key, id value) {
    return [NSString stringWithFormat:@"%@=%@", key, value];
}

static NSString *newAuthHeader(NSURL *url) {
    NSMutableString *string = [NSMutableString stringWithString:@"Sentry "];
    [string appendFormat:@"%@,", newHeaderPart(@"sentry_version", SentryServerVersionString)];
    [string appendFormat:@"%@,", newHeaderPart(@"sentry_client", [NSString stringWithFormat:@"sentry-cocoa/%@", SentryMeta.versionString])];
    [string appendFormat:@"%@,", newHeaderPart(@"sentry_timestamp", @((NSInteger) [[NSDate date] timeIntervalSince1970]))];
    [string appendFormat:@"%@", newHeaderPart(@"sentry_key", url.user)];
    if (nil != url.password) {
        [string appendFormat:@",%@", newHeaderPart(@"sentry_secret", url.password)];
    }
    return string;
}

@end

NS_ASSUME_NONNULL_END
