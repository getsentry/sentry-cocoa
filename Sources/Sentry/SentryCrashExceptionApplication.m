//
//  SentryCrashExceptionApplication.m
//  Sentry
//
//  Created by Daniel Griesser on 31.08.17.
//  Copyright © 2017 Sentry. All rights reserved.
//


#if __has_include(<Sentry/Sentry.h>)

#import <Sentry/SentryDefines.h>
#import <Sentry/SentryCrashExceptionApplication.h>

#else
#import "SentryDefines.h"
#import "SentryCrashExceptionApplication.h"
#endif

#if __has_include(<KSCrash/KSCrash.h>)
#import <KSCrash/KSCrash.h>
#elif __has_include("KSCrash.h")
#import "KSCrash.h"
#endif

@implementation SentryCrashExceptionApplication

#if TARGET_OS_OSX

- (void)reportException:(NSException *)exception {
    #if WITH_KSCRASH
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{ @"NSApplicationCrashOnExceptions": @YES }];
    if (nil != KSCrash.sharedInstance.uncaughtExceptionHandler && nil != exception) {
        KSCrash.sharedInstance.uncaughtExceptionHandler(exception);
    }
    #endif
    [super reportException:exception];
}
#endif

@end
