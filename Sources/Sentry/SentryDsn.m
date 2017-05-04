//
//  SentryDsn.m
//  Sentry
//
//  Created by Daniel Griesser on 03/05/2017.
//  Copyright © 2017 Sentry. All rights reserved.
//

#import <Sentry/SentryDsn.h>
#import <Sentry/SentryError.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentryDsn ()

@property(nonatomic, copy) NSURL *dsn;

@end

@implementation SentryDsn

- (instancetype)initWithString:(NSString *)dsnString didFailWithError:(NSError *_Nullable *_Nullable)error {
    self = [super init];
    if (self) {
        self.dsn = [self convertDsnString:dsnString didFailWithError:error];
    }
    return self;
}

- (nullable NSURL *)convertDsnString:(NSString *)dsnString didFailWithError:(NSError *_Nullable *_Nullable)error {
    dsnString = [dsnString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSSet *allowedSchemes = [NSSet setWithObjects:@"http", @"https", nil];
    NSURL *url = [NSURL URLWithString:dsnString];
    if (nil == url.scheme) {
        *error = NSErrorFromSentryError(kInvalidDSNError, @"URL scheme of DSN is missing");
        return nil;
    }
    if (![allowedSchemes containsObject:url.scheme]) {
        *error = NSErrorFromSentryError(kInvalidDSNError, @"Unrecognized URL scheme in DSN");
        return nil;
    }
    if (nil == url.host || url.host.length == 0) {
        *error = NSErrorFromSentryError(kInvalidDSNError, @"Host component of DSN is missing");
        return nil;
    }
    if (nil == url.user) {
        *error = NSErrorFromSentryError(kInvalidDSNError, @"User component of DSN is missing");
        return nil;
    }
    if (nil == url.password) {
        *error = NSErrorFromSentryError(kInvalidDSNError, @"Password component of DSN is missing");
        return nil;
    }
    if (url.pathComponents.count < 2) {
        *error = NSErrorFromSentryError(kInvalidDSNError, @"Project ID path component of DSN is missing");
        return nil;
    }
    return url;
}

@end

NS_ASSUME_NONNULL_END
