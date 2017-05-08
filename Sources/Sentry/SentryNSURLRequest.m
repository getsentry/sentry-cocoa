//
//  SentryNSURLRequest.m
//  Sentry
//
//  Created by Daniel Griesser on 05/05/2017.
//  Copyright © 2017 Sentry. All rights reserved.
//

#if __has_include(<Sentry/Sentry.h>)

#import <Sentry/SentryDsn.h>
#import <Sentry/SentryNSURLRequest.h>
#import <Sentry/SentryClient.h>
#import <Sentry/SentryEvent.h>
#import <Sentry/NSData+Compression.h>

#else
#import "SentryDsn.h"
#import "SentryNSURLRequest.h"
#import "SentryClient.h"
#import "SentryEvent.h"
#import "NSData+Compression.h"
#endif

NS_ASSUME_NONNULL_BEGIN

NSString *const SentryServerVersionString = @"7";

@interface SentryNSURLRequest ()

@property(nonatomic, strong) SentryDsn *dsn;

@end

@implementation SentryNSURLRequest

- (_Nullable instancetype)initStoreRequestWithDsn:(SentryDsn *)dsn andEvent:(SentryEvent *)event {
    NSURL *apiURL = [self.class getStoreUrlFromDsn:dsn];
    // TODO dont fix timeout here
    self = [super initWithURL:apiURL cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:15];
    if (self) {
        NSString *authHeader = newAuthHeader(dsn.url);
        
        self.HTTPMethod = @"POST";
        [self setValue:authHeader forHTTPHeaderField:@"X-Sentry-Auth"];
        [self setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        [self setValue:@"sentry-cocoa" forHTTPHeaderField:@"User-Agent"];
        [self setValue:@"gzip" forHTTPHeaderField:@"Content-Encoding"];
        
        NSError *error = nil;
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:event.serialized
                                                           options:0
                                                             error:&error];
        if (nil != error) {
            [SentryLog logWithMessage:error.localizedDescription andLevel:kSentryLogLevelError];
            return nil;
        }
        self.HTTPBody = [jsonData gzippedWithCompressionLevel:-1 error:&error];
        if (nil != error) {
            [SentryLog logWithMessage:error.localizedDescription andLevel:kSentryLogLevelError];
            return nil;
        }
    }
    return self;
}

+ (NSURL *)getStoreUrlFromDsn:(SentryDsn *)dsn {
    NSURL *url = dsn.url;
    NSString *projectId = url.pathComponents[1];
    NSURLComponents *components = [NSURLComponents new];
    components.scheme = url.scheme;
    components.host = url.host;
    components.port = url.port;
    components.path = [NSString stringWithFormat:@"/api/%@/store/", projectId];
    return components.URL;
}

static NSString *newHeaderPart(NSString *key, id value) {
    return [NSString stringWithFormat:@"%@=%@", key, value];
}

static NSString *newAuthHeader(NSURL *url) {
    NSMutableString *string = [NSMutableString stringWithString:@"Sentry "];

    [string appendFormat:@"%@,", newHeaderPart(@"sentry_version", SentryServerVersionString)];
    [string appendFormat:@"%@,", newHeaderPart(@"sentry_client", [NSString stringWithFormat:@"sentry-cocoa/%@", SentryClient.versionString])];
    [string appendFormat:@"%@,", newHeaderPart(@"sentry_timestamp", @((NSInteger) [[NSDate date] timeIntervalSince1970]))];
    [string appendFormat:@"%@,", newHeaderPart(@"sentry_key", url.user)];
    [string appendFormat:@"%@", newHeaderPart(@"sentry_secret", url.password)];

    return string;
}

@end

NS_ASSUME_NONNULL_END
