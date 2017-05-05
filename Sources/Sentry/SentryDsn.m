//
//  SentryDsn.m
//  Sentry
//
//  Created by Daniel Griesser on 03/05/2017.
//  Copyright © 2017 Sentry. All rights reserved.
//

#if __has_include(<Sentry/Sentry.h>)
#import <Sentry/SentryDsn.h>
#import <Sentry/SentryClient.h>
#import <Sentry/SentryError.h>
#else
#import "SentryDsn.h"
#import "SentryClient.h"
#import "SentryError.h"
#endif

NS_ASSUME_NONNULL_BEGIN

@interface SentryDsn ()

@property(nonatomic, strong) NSURL *dsn;

@end

@implementation SentryDsn

- (instancetype)initWithString:(NSString *)dsnString didFailWithError:(NSError *_Nullable *_Nullable)error {
    self = [super init];
    if (self) {
        self.dsn = [self convertDsnString:dsnString didFailWithError:error];
    }
    return self;
}

- (NSURL *_Nullable)convertDsnString:(NSString *)dsnString didFailWithError:(NSError *_Nullable *_Nullable)error {
    NSString *trimmedDsnString = [dsnString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSSet *allowedSchemes = [NSSet setWithObjects:@"http", @"https", nil];
    NSURL *url = [NSURL URLWithString:trimmedDsnString];
    NSString *errorMessage = nil;
    if (nil == url.scheme) {
        errorMessage = @"URL scheme of DSN is missing";
        url = nil;
    }
    if (![allowedSchemes containsObject:url.scheme]) {
        errorMessage = @"Unrecognized URL scheme in DSN";
        url = nil;
    }
    if (nil == url.host || url.host.length == 0) {
        errorMessage = @"Host component of DSN is missing";
        url = nil;
    }
    if (nil == url.user) {
        errorMessage = @"User component of DSN is missing";
        url = nil;
    }
    if (nil == url.password) {
        errorMessage = @"Password component of DSN is missing";
        url = nil;
    }
    if (url.pathComponents.count < 2) {
        errorMessage = @"Project ID path component of DSN is missing";
        url = nil;
    }
    if (nil == url) {
        if (nil != error) *error = NSErrorFromSentryError(kInvalidDsnError, errorMessage);
        return nil;
    }
    return url;
}


static NSURL *extractURLFromDSN(NSString *dsn)
{
    NSURL *url = [NSURL URLWithString:dsn];
    NSString *projectID = url.pathComponents[1];
    NSURLComponents *components = [NSURLComponents new];
    components.scheme = url.scheme;
    components.host = url.host;
    components.port = url.port;
    components.path = [NSString stringWithFormat:@"/api/%@/store/", projectID];
    return components.URL;
}

static NSString *newHeaderPart(NSString *key, id value)
{
    return [NSString stringWithFormat:@"%@=%@", key, value];
}

static NSString *newAuthHeader(NSURL *url)
{
    NSMutableString *string = [NSMutableString stringWithString:@"Sentry "];

    [string appendFormat:@"%@,", newHeaderPart(@"sentry_version", SentryServerVersionString)];
    [string appendFormat:@"%@,", newHeaderPart(@"sentry_client", [NSString stringWithFormat:@"sentry-objc/%@", SentryClientVersionString])];
    [string appendFormat:@"%@,", newHeaderPart(@"sentry_timestamp", @((NSInteger)[[NSDate date] timeIntervalSince1970]))];
    [string appendFormat:@"%@,", newHeaderPart(@"sentry_key", url.user)];
    [string appendFormat:@"%@,", newHeaderPart(@"sentry_secret", url.password)];

    [string deleteCharactersInRange:NSMakeRange([string length]-1, 1)]; // We strip the last slash
    return string;
}

@end

NS_ASSUME_NONNULL_END
