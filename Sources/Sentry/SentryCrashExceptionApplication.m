//
//  SentryCrashExceptionApplication.m
//  Sentry
//
//  Created by Daniel Griesser on 31.08.17.
//  Copyright © 2017 Sentry. All rights reserved.
//

#import "SentryDefines.h"
#import "SentryCrashExceptionApplication.h"
#import "SentryCrash.h"

@implementation SentryCrashExceptionApplication

#if TARGET_OS_OSX

- (void)reportException:(NSException *)exception {
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{ @"NSApplicationCrashOnExceptions": @YES }];
    if (nil != SentryCrash.sharedInstance.uncaughtExceptionHandler && nil != exception) {
        SentryCrash.sharedInstance.uncaughtExceptionHandler(exception);
    }
    [super reportException:exception];
}
#endif

@end
