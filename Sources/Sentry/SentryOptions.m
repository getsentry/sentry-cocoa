//
//  SentryOptions.m
//  Sentry
//
//  Created by Daniel Griesser on 12.03.19.
//  Copyright © 2019 Sentry. All rights reserved.
//

#if __has_include(<Sentry/Sentry.h>)

#import <Sentry/SentryOptions.h>
#import <Sentry/SentryDsn.h>
#import <Sentry/SentryError.h>
#import <Sentry/SentryLog.h>

#else
#import "SentryOptions.h"
#import "SentryDsn.h"
#import "SentryError.h"
#import "SentryLog.h"
#endif

@implementation SentryOptions

+ (NSArray<NSString *>*)defaultIntegrations {
    return @[
        @"SentryCrashIntegration"
    ];
}

- (_Nullable instancetype)initWithDict:(NSDictionary<NSString *, id> *)options
                      didFailWithError:(NSError *_Nullable *_Nullable)error {
    self = [super init];
    if (self) {
        [self validateOptions:options didFailWithError:error];
        if (nil != error && nil != *error) {
            return nil;
        }
    }
    return self;
}

- (void)validateOptions:(NSDictionary<NSString *, id> *)options
       didFailWithError:(NSError *_Nullable *_Nullable)error {
    if (nil == [options valueForKey:@"dsn"] || ![[options valueForKey:@"dsn"] isKindOfClass:[NSString class]]) {
        *error = NSErrorFromSentryError(kSentryErrorInvalidDsnError, @"Dsn cannot be empty");
        return;
    }
    self.dsn = [[SentryDsn alloc] initWithString:[options valueForKey:@"dsn"] didFailWithError:error];
    
    if ([[options objectForKey:@"release"] isKindOfClass:[NSString class]]) {
        self.releaseName = [options objectForKey:@"release"];
    }
    
    if ([[options objectForKey:@"environment"] isKindOfClass:[NSString class]]) {
        self.environment = [options objectForKey:@"environment"];
    }
    
    if ([[options objectForKey:@"dist"] isKindOfClass:[NSString class]]) {
        self.dist = [options objectForKey:@"dist"];
    }
    
    if (nil != [options objectForKey:@"enabled"]) {
        self.enabled = [NSNumber numberWithBool:[[options objectForKey:@"enabled"] boolValue]];
    } else {
        self.enabled = @YES;
    }

    if (nil != [options objectForKey:@"max_breadcrumbs"]) {
        self.maxBreadcrumbs = [[options objectForKey:@"max_breadcrumbs"] unsignedIntValue];
    } else {
        // fallback value
        self.maxBreadcrumbs = [@100 unsignedIntValue];
    }

    if (nil != [options objectForKey:@"beforeSend"]) {
        self.beforeSend = [options objectForKey:@"beforeSend"];
    }

    if (nil != [options objectForKey:@"integrations"]) {
        self.integrations = [options objectForKey:@"integrations"];
    } else {
        // fallback to defaultIntegrations
        self.integrations = [SentryOptions defaultIntegrations];
    }

    float sampleRate = [[options objectForKey:@"sample_rate"] floatValue];
    if (sampleRate < 0 || sampleRate > 1) {
        [SentryLog logWithMessage:@"sampleRate must be between 0.0 and 1.0" andLevel:kSentryLogLevelError];
    } else {
        self.sampleRate = sampleRate;
    }
}

/**
 checks if event should be sent according to sampleRate
 returns BOOL
 */
- (BOOL)checkSampleRate {
    if (self.sampleRate < 0 || self.sampleRate > 1) {
        [SentryLog logWithMessage:@"sampleRate must be between 0.0 and 1.0, checkSampleRate is skipping check and returns YES" andLevel:kSentryLogLevelError];
        return YES;
    }
    return (self.sampleRate >= ((double)arc4random() / 0x100000000));
}

@end
