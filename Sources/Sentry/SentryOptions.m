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
#import <Sentry/SentrySDK.h>

#else
#import "SentryOptions.h"
#import "SentryDsn.h"
#import "SentryError.h"
#import "SentryLog.h"
#import "SentrySDK.h"
#endif

@implementation SentryOptions

+ (NSArray<NSString *>*)defaultIntegrations {
    return @[
        @"SentryCrashIntegration",
        @"SentryUIKitMemoryWarningIntegration",
        @"SentryAutoBreadcrumbTrackingIntegration"
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

/**
 populates all `SentryOptions` values from `options` dict using fallbacks/defaults if needed.
 */
- (void)validateOptions:(NSDictionary<NSString *, id> *)options
       didFailWithError:(NSError *_Nullable *_Nullable)error {
    
    if (nil != [options objectForKey:@"debug"]) {
        self.debug = [NSNumber numberWithBool:[[options objectForKey:@"debug"] boolValue]];
    } else {
        self.debug = @NO;
    }

    if ([self.debug isEqual:@YES])  {
        SentrySDK.logLevel = kSentryLogLevelDebug;
    } else {
        SentrySDK.logLevel = kSentryLogLevelError;
    }
    
    if (nil == [options valueForKey:@"dsn"] || ![[options valueForKey:@"dsn"] isKindOfClass:[NSString class]]) {
        self.enabled = @NO;
        [SentryLog logWithMessage:@"DSN is empty, will disable the SDK" andLevel:kSentryLogLevelDebug];
        return;
    }
    
    self.dsn = [[SentryDsn alloc] initWithString:[options valueForKey:@"dsn"] didFailWithError:error];
    if (nil != error && nil != *error) {
        self.enabled = @NO;
    }
    
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

    if (nil != [options objectForKey:@"maxBreadcrumbs"]) {
        self.maxBreadcrumbs = [[options objectForKey:@"maxBreadcrumbs"] unsignedIntValue];
    } else {
        // fallback value
        self.maxBreadcrumbs = [@100 unsignedIntValue];
    }

    if (nil != [options objectForKey:@"beforeSend"]) {
        self.beforeSend = [options objectForKey:@"beforeSend"];
    }

    if (nil != [options objectForKey:@"beforeBreadcrumb"]) {
        self.beforeBreadcrumb = [options objectForKey:@"beforeBreadcrumb"];
    }

    if (nil != [options objectForKey:@"integrations"]) {
        self.integrations = [options objectForKey:@"integrations"];
    } else {
        // fallback to defaultIntegrations
        self.integrations = [SentryOptions defaultIntegrations];
    }

    NSNumber *sampleRate = [options objectForKey:@"sampleRate"];
    if (nil == sampleRate || [sampleRate floatValue] < 0 || [sampleRate floatValue] > 1.0) {
        self.sampleRate = @1;
    } else {
        self.sampleRate = sampleRate;
    }
}

@end
