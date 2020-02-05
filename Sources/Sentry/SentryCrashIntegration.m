//
//  SentryCrashIntegration.m
//  Sentry
//
//  Created by Klemens Mantzos on 04.12.19.
//  Copyright © 2019 Sentry. All rights reserved.
//

#if __has_include(<Sentry/Sentry.h>)
#import <Sentry/SentryCrashIntegration.h>
#import <Sentry/SentryInstallation.h>
#import <Sentry/SentryOptions.h>
#import <Sentry/SentryLog.h>
#import <Sentry/SentryEvent.h>
#import <Sentry/SentryContext.h>
#import <Sentry/SentryGlobalEventProcessor.h>
#import <Sentry/SentrySDK.h>
#else
#import "SentryCrashIntegration.h"
#import "SentryInstallation.h"
#import "SentryOptions.h"
#import "SentryLog.h"
#import "SentryEvent.h"
#import "SentryContext.h"
#import "SentryGlobalEventProcessor.h"
#import "SentrySDK.h"
#endif

#if SENTRY_HAS_UIKIT
#import <UIKit/UIKit.h>
#endif


static SentryInstallation *installation = nil;

@interface SentryCrashIntegration ()

@property(nonatomic, weak) SentryOptions *options;

@end

@implementation SentryCrashIntegration

/**
 * Wrapper for `SentryCrash.sharedInstance.systemInfo`, to cash the result.
 *
 * @return NSDictionary system info.
 */
+ (NSDictionary *)systemInfo {
    static NSDictionary *sharedInfo = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInfo = SentryCrash.sharedInstance.systemInfo;
    });
    return sharedInfo;
}

- (BOOL)installWithOptions:(nonnull SentryOptions *)options {
    self.options = options;
    NSError *error = nil;
    BOOL isInstalled = [self startCrashHandlerWithError:&error];
    if (isInstalled == YES) {
        [self addEventProcessor];
    }
    return isInstalled;
}

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wunused-parameter"
- (BOOL)startCrashHandlerWithError:(NSError *_Nullable *_Nullable)error {
    static dispatch_once_t onceToken = 0;
    dispatch_once(&onceToken, ^{
        installation = [[SentryInstallation alloc] init];
        [installation install];
        [installation sendAllReports];
    });
    return YES;
}
#pragma GCC diagnostic pop

// TODO(fetzig) this was in client, used for testing only, not sure if we can
// still use this (for testing). maybe move it to hub or static-sdk?
- (void)reportUserException:(NSString *)name
                     reason:(NSString *)reason
                   language:(NSString *)language
                 lineOfCode:(NSString *)lineOfCode
                 stackTrace:(NSArray *)stackTrace
              logAllThreads:(BOOL)logAllThreads
           terminateProgram:(BOOL)terminateProgram {

    if (nil == installation) {
        [SentryLog logWithMessage:@"SentryCrash has not been initialized, call startCrashHandlerWithError" andLevel:kSentryLogLevelError];
        return;
    }

    [SentryCrash.sharedInstance reportUserException:name
                                             reason:reason
                                           language:language
                                         lineOfCode:lineOfCode
                                         stackTrace:stackTrace
                                      logAllThreads:logAllThreads
                                   terminateProgram:terminateProgram];
    [installation sendAllReports];
}

- (BOOL)crashedLastLaunch {
    return SentryCrash.sharedInstance.crashedLastLaunch;
}

- (void)addEventProcessor {
    [SentryLog logWithMessage:@"SentryCrashIntegration addEventProcessor" andLevel:kSentryLogLevelDebug];
    SentryEventProcessor eventProcessor = ^SentryEvent * _Nullable(SentryEvent * _Nonnull event) {
        NSString * integrationName = NSStringFromClass(SentryCrashIntegration.class);

        // skip early if integration (and therefore this event processor) isn't active on current client
        if (NO == [SentrySDK.currentHub isIntegrationActiveInBoundClient:integrationName]) {
            [SentryLog logWithMessage:@"SentryCrashIntegration event processor exits early! Triggered but current client has no SentryCrashIntegration installed." andLevel:kSentryLogLevelError];
            return event;
        }

        if (nil == event.context) {
            event.context = [[SentryContext alloc] init];
        }

        // OS

        NSMutableDictionary *osData = [NSMutableDictionary new];

#if TARGET_OS_OSX || TARGET_OS_MACCATALYST
        [osData setValue:@"macOS" forKey:@"name"];
#elif TARGET_OS_IOS
        [osData setValue:@"iOS" forKey:@"name"];
#elif TARGET_OS_TV
        [osData setValue:@"tvOS" forKey:@"name"];
#elif TARGET_OS_WATCH
        [osData setValue:@"watchOS" forKey:@"name"];
#endif

#if SENTRY_HAS_UIDEVICE
        [osData setValue:[UIDevice currentDevice].systemVersion forKey:@"version"];
#else
        NSOperatingSystemVersion version = [NSProcessInfo processInfo].operatingSystemVersion;
        NSString *systemVersion = [NSString stringWithFormat:@"%d.%d.%d", (int) version.majorVersion, (int) version.minorVersion, (int) version.patchVersion];
        [osData setValue:systemVersion forKey:@"version"];
#endif

        NSDictionary *systemInfo = [SentryCrashIntegration systemInfo];
        [osData setValue:systemInfo[@"osVersion"] forKey:@"build"];
        [osData setValue:systemInfo[@"kernelVersion"] forKey:@"kernel_version"];
        [osData setValue:systemInfo[@"isJailbroken"] forKey:@"rooted"];

        event.context.osContext = osData;

        // DEVICE

        NSMutableDictionary *deviceData = [NSMutableDictionary new];

#if TARGET_OS_SIMULATOR
        [deviceData setValue:@(YES) forKey:@"simulator"];
#endif

        NSString *family = [[systemInfo[@"systemName"] componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] firstObject];

        [deviceData setValue:family forKey:@"family"];
        [deviceData setValue:systemInfo[@"cpuArchitecture"] forKey:@"arch"];
        [deviceData setValue:systemInfo[@"machine"] forKey:@"model"];
        [deviceData setValue:systemInfo[@"model"] forKey:@"model_id"];
        [deviceData setValue:systemInfo[@"freeMemory"] forKey:@"free_memory"];
        [deviceData setValue:systemInfo[@"usableMemory"] forKey:@"usable_memory"];
        [deviceData setValue:systemInfo[@"memorySize"] forKey:@"memory_size"];
        [deviceData setValue:systemInfo[@"storageSize"] forKey:@"storage_size"];
        [deviceData setValue:systemInfo[@"bootTime"] forKey:@"boot_time"];
        [deviceData setValue:systemInfo[@"timezone"] forKey:@"timezone"];

        event.context.deviceContext = deviceData;

        // APP

        NSMutableDictionary *appData = [NSMutableDictionary new];
        NSDictionary *infoDict = [[NSBundle mainBundle] infoDictionary];

        [appData setValue:infoDict[@"CFBundleIdentifier"] forKey:@"app_identifier"];
        [appData setValue:infoDict[@"CFBundleName"] forKey:@"app_name"];
        [appData setValue:infoDict[@"CFBundleVersion"] forKey:@"app_build"];
        [appData setValue:infoDict[@"CFBundleShortVersionString"] forKey:@"app_version"];

        [appData setValue:systemInfo[@"appStartTime"] forKey:@"app_start_time"];
        [appData setValue:systemInfo[@"deviceAppHash"] forKey:@"device_app_hash"];
        [appData setValue:systemInfo[@"appID"] forKey:@"app_id"];
        [appData setValue:systemInfo[@"buildType"] forKey:@"build_type"];

        event.context.appContext = appData;

        return event;
    };

    [SentryGlobalEventProcessor.shared addEventProcessor:eventProcessor];
}

@end
