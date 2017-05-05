//
//  SentryDsn.m
//  Sentry
//
//  Created by Daniel Griesser on 03/05/2017.
//  Copyright © 2017 Sentry. All rights reserved.
//

#if __has_include(<Sentry/Sentry.h>)
#import <Sentry/SentryDsn.h>
#import <Sentry/SentryError.h>
#else
#import "SentryDsn.h"
#import "SentryError.h"
#endif

NS_ASSUME_NONNULL_BEGIN

@interface SentryDsn ()

@property(nonatomic, retain) NSURL *dsn;

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
    dsnString = [dsnString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSSet *allowedSchemes = [NSSet setWithObjects:@"http", @"https", nil];
    NSURL *url = [NSURL URLWithString:dsnString];
    if (nil == url.scheme) {
        if (nil != error) *error = NSErrorFromSentryError(kInvalidDsnError, @"URL scheme of DSN is missing");
        return nil;
    }
    if (![allowedSchemes containsObject:url.scheme]) {
        if (nil != error) *error = NSErrorFromSentryError(kInvalidDsnError, @"Unrecognized URL scheme in DSN");
        return nil;
    }
    if (nil == url.host || url.host.length == 0) {
        if (nil != error) *error = NSErrorFromSentryError(kInvalidDsnError, @"Host component of DSN is missing");
        return nil;
    }
    if (nil == url.user) {
        if (nil != error) *error = NSErrorFromSentryError(kInvalidDsnError, @"User component of DSN is missing");
        return nil;
    }
    if (nil == url.password) {
        if (nil != error) *error = NSErrorFromSentryError(kInvalidDsnError, @"Password component of DSN is missing");
        return nil;
    }
    if (url.pathComponents.count < 2) {
        if (nil != error) *error = NSErrorFromSentryError(kInvalidDsnError, @"Project ID path component of DSN is missing");
        return nil;
    }
    return url;
}

@end

NS_ASSUME_NONNULL_END
