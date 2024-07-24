//
//  SentryBeforeCrashIntegration.m
//  Sentry
//
//  Created by Filip Busic on 10/16/23.
//  Copyright © 2023 Sentry. All rights reserved.
//

#import "SentryBeforeCrashIntegration.h"
#import "SentryCrashC.h"

static void (^g_beforeCrashOptionsCallback)(NSString *) = nil;

// Define a callback function
void beforeCrashCallback(const char *eventID) {
    if (g_beforeCrashOptionsCallback) {
        g_beforeCrashOptionsCallback([NSString stringWithUTF8String:eventID]);
    }
}

@implementation SentryBeforeCrashIntegration

- (BOOL)installWithOptions:(nonnull SentryOptions *)options
{
    if (![super installWithOptions:options]) {
        return NO;
    }
    
    if (options.enableBeforeCrashHandler) {
        g_beforeCrashOptionsCallback = options.beforeCrash;
        sentrycrash_setBeforeCrashCallback(&beforeCrashCallback);
    }
    
    return options.enableBeforeCrashHandler;
}

- (void)uninstall
{
    g_beforeCrashOptionsCallback = nil;
    sentrycrash_setBeforeCrashCallback(nil);
}

- (SentryIntegrationOption)integrationOptions
{
    return kIntegrationOptionDebuggerNotAttached;
}

@end
