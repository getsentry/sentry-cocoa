//
//  SentryCrashIntegration.m
//  Sentry
//
//  Created by Klemens Mantzos on 04.12.19.
//  Copyright © 2019 Sentry. All rights reserved.
//

#import "SentryCrashIntegration.h"
#import "SentryInstallation.h"
#import "SentryOptions.h"
#import "SentryLog.h"
#import "SentryEvent.h"
#import "SentryContext.h"
#import "SentryGlobalEventProcessor.h"
#import "SentrySDK.h"

#import <sys/types.h>
#import <sys/sysctl.h>

#if SENTRY_HAS_UIKIT
#import <UIKit/UIKit.h>
#endif

#import <CrashReporter/CrashReporter.h>

static SentryInstallation *installation = nil;

@interface SentryCrashIntegration ()

@property(nonatomic, weak) SentryOptions *options;

@end

@implementation SentryCrashIntegration


static bool is_debugger_running (void) {
#if !TARGET_OS_IPHONE
    return false;
#endif

    struct kinfo_proc info;
    size_t info_size = sizeof(info);
    int name[4];
    
    name[0] = CTL_KERN;
    name[1] = KERN_PROC;
    name[2] = KERN_PROC_PID;
    name[3] = getpid();
    
    if (sysctl(name, 4, &info, &info_size, NULL, 0) == -1) {
        NSLog(@"sysctl() failed: %s", strerror(errno));
        return false;
    }

    if ((info.kp_proc.p_flag & P_TRACED) != 0)
        return true;
    
    return false;
}

- (BOOL)installWithOptions:(nonnull SentryOptions *)options {
    self.options = options;
    NSError *error = nil;
//    BOOL isInstalled = [self startCrashHandlerWithError:&error];
//    if (isInstalled == YES) {
//        [self addEventProcessor];
//    }
    PLCrashReporterConfig *config = [[PLCrashReporterConfig alloc] initWithSignalHandlerType: PLCrashReporterSignalHandlerTypeMach
                                                                           symbolicationStrategy: PLCrashReporterSymbolicationStrategyAll] ;
       PLCrashReporter *reporter = [[PLCrashReporter alloc] initWithConfiguration: config];
    if (!is_debugger_running()) {
        [reporter enableCrashReporter];
    }
    
    if ([reporter hasPendingCrashReport]) {
        NSData *data = [reporter loadPendingCrashReportDataAndReturnError: &error];
        if (data == nil) {
            NSLog(@"Failed to load crash report data: %@", error);
        }
        
        NSFileManager *fm = [NSFileManager defaultManager];
        NSError *error;
        
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *documentsDirectory = [paths objectAtIndex:0];
        if (![fm createDirectoryAtPath: documentsDirectory withIntermediateDirectories: YES attributes:nil error: &error]) {
            NSLog(@"Could not create documents directory: %@", error);
        }

        PLCrashReport *report = [[PLCrashReport alloc] initWithData: data error: &error];
        NSString *text = [PLCrashReportTextFormatter stringValueForCrashReport: report withTextFormat: PLCrashReportTextFormatiOS];
        

        NSString *outputPath = [documentsDirectory stringByAppendingPathComponent: @"demo2.plcrash"];
        NSLog(@"%@", outputPath);
        if (![data writeToFile: outputPath atomically: YES]) {
            NSLog(@"Failed to write crash report");
        }
        
        [reporter purgePendingCrashReport];
        NSLog(@"%@", text);
    }
    
    return YES;
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

        // TODO
//        NSDictionary *systemInfo = [SentryCrashIntegration systemInfo];
//        [osData setValue:systemInfo[@"osVersion"] forKey:@"build"];
//        [osData setValue:systemInfo[@"kernelVersion"] forKey:@"kernel_version"];
//        [osData setValue:systemInfo[@"isJailbroken"] forKey:@"rooted"];

        event.context.osContext = osData;

        // DEVICE

        NSMutableDictionary *deviceData = [NSMutableDictionary new];

#if TARGET_OS_SIMULATOR
        [deviceData setValue:@(YES) forKey:@"simulator"];
#endif
// TODO
//        NSString *family = [[systemInfo[@"systemName"] componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] firstObject];
//
//        [deviceData setValue:family forKey:@"family"];
//        [deviceData setValue:systemInfo[@"cpuArchitecture"] forKey:@"arch"];
//        [deviceData setValue:systemInfo[@"machine"] forKey:@"model"];
//        [deviceData setValue:systemInfo[@"model"] forKey:@"model_id"];
//        [deviceData setValue:systemInfo[@"freeMemory"] forKey:@"free_memory"];
//        [deviceData setValue:systemInfo[@"usableMemory"] forKey:@"usable_memory"];
//        [deviceData setValue:systemInfo[@"memorySize"] forKey:@"memory_size"];
//        [deviceData setValue:systemInfo[@"storageSize"] forKey:@"storage_size"];
//        [deviceData setValue:systemInfo[@"bootTime"] forKey:@"boot_time"];
//        [deviceData setValue:systemInfo[@"timezone"] forKey:@"timezone"];

        event.context.deviceContext = deviceData;

        // APP

        NSMutableDictionary *appData = [NSMutableDictionary new];
        NSDictionary *infoDict = [[NSBundle mainBundle] infoDictionary];

        [appData setValue:infoDict[@"CFBundleIdentifier"] forKey:@"app_identifier"];
        [appData setValue:infoDict[@"CFBundleName"] forKey:@"app_name"];
        [appData setValue:infoDict[@"CFBundleVersion"] forKey:@"app_build"];
        [appData setValue:infoDict[@"CFBundleShortVersionString"] forKey:@"app_version"];

        // TODO
//        [appData setValue:systemInfo[@"appStartTime"] forKey:@"app_start_time"];
//        [appData setValue:systemInfo[@"deviceAppHash"] forKey:@"device_app_hash"];
//        [appData setValue:systemInfo[@"appID"] forKey:@"app_id"];
//        [appData setValue:systemInfo[@"buildType"] forKey:@"build_type"];

        event.context.appContext = appData;

        return event;
    };

    [SentryGlobalEventProcessor.shared addEventProcessor:eventProcessor];
}

@end
