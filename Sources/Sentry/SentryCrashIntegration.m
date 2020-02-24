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
#import "SentryDebugMeta.h"
#import "SentryThread.h"
#import "SentryStacktrace.h"
#import "SentryFrame.h"
#import "SentryException.h"
#import "SentryContext.h"
#import "SentryUser.h"
#import "SentryMechanism.h"
#import "NSDate+SentryExtras.h"

#import <CrashReporter/CrashReporter.h>

#import <sys/types.h>
#import <sys/sysctl.h>
#include <mach-o/arch.h>

#if SENTRY_HAS_UIKIT
#import <UIKit/UIKit.h>
#endif

#import <CrashReporter/CrashReporter.h>

#define CHECK_SYSCTL_NAME(TYPE, CALL) \
if(0 != (CALL)) \
{ \
    return 0; \
}

#define RETURN_NAME_FOR_ENUM(A) case A: return #A

static PLCrashReporter *reporter = nil;

@interface SentryCrashIntegration ()

@property(nonatomic, weak) SentryOptions *options;

@end

@implementation SentryCrashIntegration

- (void)installWithOptions:(nonnull SentryOptions *)options {
    self.options = options;

    [self startCrashHandler];
        
    [self addEventProcessor];
       
    if ([reporter hasPendingCrashReport]) {
        NSData *data = [reporter loadPendingCrashReportDataAndReturnError:nil];
        
        NSFileManager *fm = [NSFileManager defaultManager];
        NSError *error;

        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *documentsDirectory = [paths objectAtIndex:0];
        if (![fm createDirectoryAtPath: documentsDirectory withIntermediateDirectories: YES attributes:nil error: &error]) {
            NSLog(@"Could not create documents directory: %@", error);
        }

        PLCrashReport *report = [[PLCrashReport alloc] initWithData:data error:&error];
        NSString *text = [PLCrashReportTextFormatter stringValueForCrashReport:report withTextFormat:PLCrashReportTextFormatiOS];
        NSLog(@"%@", text);
        
        NSString *outputPath = [documentsDirectory stringByAppendingPathComponent:@"nsexception.plcrash"];
        NSLog(@"%@", outputPath);
        if (![data writeToFile: outputPath atomically: YES]) {
            NSLog(@"Failed to write crash report");
        }

        SentryEvent *event = [self convertPLCrashReportToEvent:report];
        
        [SentrySDK captureEvent:event];
        
        [reporter purgePendingCrashReport];
    }
}

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wunused-parameter"
- (BOOL)startCrashHandler {
    static dispatch_once_t onceToken = 0;
    dispatch_once(&onceToken, ^{
        reporter = [[PLCrashReporter alloc] initWithConfiguration:[[PLCrashReporterConfig alloc] initWithSignalHandlerType:PLCrashReporterSignalHandlerTypeMach
                                                                                                     symbolicationStrategy:PLCrashReporterSymbolicationStrategyAll]];
        if (!is_debugger_running()) {
           [reporter enableCrashReporter];
       } else {
           [SentryLog logWithMessage:@"Debugger is attached, will not collect crashes." andLevel:kSentryLogLevelDebug];
       }
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

        // Only generate a live report if we don't have event.debugMeta attached, otherwise this event already spawned out of a crash
        if (nil == event.debugMeta) {
            PLCrashReport *report = [[PLCrashReport alloc] initWithData:[reporter generateLiveReport] error:nil];
            [SentryCrashIntegration addOsContextToEvent:event fromPLCrashReport:report];
            [SentryCrashIntegration addDeviceContextToEvent:event fromPLCrashReport:report];
            [SentryCrashIntegration addAppContextToEvent:event fromPLCrashReport:report];
        }

        return event;
    };

    [SentryGlobalEventProcessor.shared addEventProcessor:eventProcessor];
}


int sentry_stringForName(const char* const  name,
                              char* const value,
                              const int maxSize)
{
    size_t size = value == NULL ? 0 : (size_t)maxSize;

    CHECK_SYSCTL_NAME(string, sysctlbyname(name, value, &size, NULL, 0));

    return (int)size;
}

uint64_t sentry_uint64ForName(const char* const name)
{
    uint64_t value = 0;
    size_t size = sizeof(value);

    CHECK_SYSCTL_NAME(uint64, sysctlbyname(name, &value, &size, NULL, 0));

    return value;
}


/** Get a sysctl value as a null terminated string.
 *
 * @param name The sysctl name.
 *
 * @return The result of the sysctl call.
 */
static const char* sentry_stringSysctl(const char* name)
{
    int size = (int)sentry_stringForName(name, NULL, 0);
    if(size <= 0)
    {
        return NULL;
    }

    char* value = malloc((size_t)size);
    if(value == NULL)
    {
        return NULL;
    }

    if(sentry_stringForName(name, value, size) <= 0)
    {
        free(value);
        return NULL;
    }

    return value;
}

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

static inline NSString *hexAddress(NSNumber *value) {
    return [NSString stringWithFormat:@"0x%016llx", [value unsignedLongLongValue]];
}

const char* sentry_plcrash_mach_exceptionName(const int64_t exceptionType)
{
    switch (exceptionType)
    {
            RETURN_NAME_FOR_ENUM(EXC_BAD_ACCESS);
            RETURN_NAME_FOR_ENUM(EXC_BAD_INSTRUCTION);
            RETURN_NAME_FOR_ENUM(EXC_ARITHMETIC);
            RETURN_NAME_FOR_ENUM(EXC_EMULATION);
            RETURN_NAME_FOR_ENUM(EXC_SOFTWARE);
            RETURN_NAME_FOR_ENUM(EXC_BREAKPOINT);
            RETURN_NAME_FOR_ENUM(EXC_SYSCALL);
            RETURN_NAME_FOR_ENUM(EXC_MACH_SYSCALL);
            RETURN_NAME_FOR_ENUM(EXC_RPC_ALERT);
            RETURN_NAME_FOR_ENUM(EXC_CRASH);
    }
    return NULL;
}

/** Get the current VM stats.
 *
 * @param vmStats Gets filled with the VM stats.
 *
 * @param pageSize gets filled with the page size.
 *
 * @return true if the operation was successful.
 */
static bool VMStats(vm_statistics_data_t* const vmStats, vm_size_t* const pageSize)
{
    kern_return_t kr;
    const mach_port_t hostPort = mach_host_self();

    if((kr = host_page_size(hostPort, pageSize)) != KERN_SUCCESS)
    {
        return false;
    }

    mach_msg_type_number_t hostSize = sizeof(*vmStats) / sizeof(natural_t);
    kr = host_statistics(hostPort,
                         HOST_VM_INFO,
                         (host_info_t)vmStats,
                         &hostSize);
    if(kr != KERN_SUCCESS)
    {
        return false;
    }

    return true;
}

static uint64_t freeMemory(void)
{
    vm_statistics_data_t vmStats;
    vm_size_t pageSize;
    if(VMStats(&vmStats, &pageSize))
    {
        return ((uint64_t)pageSize) * vmStats.free_count;
    }
    return 0;
}

static uint64_t usableMemory(void)
{
    vm_statistics_data_t vmStats;
    vm_size_t pageSize;
    if(VMStats(&vmStats, &pageSize))
    {
        return ((uint64_t)pageSize) * (vmStats.active_count +
                                       vmStats.inactive_count +
                                       vmStats.wire_count +
                                       vmStats.free_count);
    }
    return 0;
}

/** Get the current CPU's architecture.
 *
 * @return The current CPU archutecture.
 */
static const char* sentry_getCPUArchForCPUType(cpu_type_t cpuType, cpu_subtype_t subType)
{
    switch(cpuType)
    {
        case CPU_TYPE_ARM:
        {
            switch (subType)
            {
                case CPU_SUBTYPE_ARM_V6:
                    return "armv6";
                case CPU_SUBTYPE_ARM_V7:
                    return "armv7";
                case CPU_SUBTYPE_ARM_V7F:
                    return "armv7f";
                case CPU_SUBTYPE_ARM_V7K:
                    return "armv7k";
#ifdef CPU_SUBTYPE_ARM_V7S
                case CPU_SUBTYPE_ARM_V7S:
                    return "armv7s";
#endif
            }
            break;
        }
        case CPU_TYPE_X86:
            return "x86";
        case CPU_TYPE_X86_64:
            return "x86_64";
    }

    return NULL;
}

+ (void)addOsContextToEvent:(SentryEvent *)event fromPLCrashReport:(PLCrashReport *)report {
        
    //    plCrashReport.systemInfo.operatingSystem PLCrashReportOperatingSystemiPhoneSimulator
    //    plCrashReport.systemInfo.operatingSystemBuild 19C57
    //    plCrashReport.systemInfo.operatingSystemVersion 13.3
    if (report.systemInfo) {
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

        [osData setValue:report.systemInfo.operatingSystemBuild forKey:@"build"];
//        [osData setValue:systemInfo[@"kernelVersion"] forKey:@"kernel_version"];
        
        if (event.context.osContext) {
            [osData addEntriesFromDictionary:event.context.osContext];
        }
        event.context.osContext = osData;
    }
    

}

+ (void)addAppContextToEvent:(SentryEvent *)event fromPLCrashReport:(PLCrashReport *)report {
    NSMutableDictionary *appData = [NSMutableDictionary new];
    NSDictionary *infoDict = [[NSBundle mainBundle] infoDictionary];
    [appData setValue:infoDict[@"CFBundleName"] forKey:@"app_name"];

    if (report) {
        [appData setValue:report.applicationInfo.applicationIdentifier forKey:@"app_identifier"];
        [appData setValue:report.applicationInfo.applicationVersion forKey:@"app_build"];
        [appData setValue:report.applicationInfo.applicationMarketingVersion forKey:@"app_version"];
    } else {
        
        [appData setValue:infoDict[@"CFBundleIdentifier"] forKey:@"app_identifier"];
        [appData setValue:infoDict[@"CFBundleName"] forKey:@"app_name"];
        [appData setValue:infoDict[@"CFBundleVersion"] forKey:@"app_build"];
        [appData setValue:infoDict[@"CFBundleShortVersionString"] forKey:@"app_version"];
    }
    
    
    // TODO
    //        [appData setValue:systemInfo[@"appStartTime"] forKey:@"app_start_time"];
    //        [appData setValue:systemInfo[@"deviceAppHash"] forKey:@"device_app_hash"];
    //        [appData setValue:systemInfo[@"appID"] forKey:@"app_id"];
    //        [appData setValue:systemInfo[@"buildType"] forKey:@"build_type"];
    
    if (event.context.appContext) {
        [appData addEntriesFromDictionary:event.context.appContext];
    }
    event.context.appContext = appData;
}

+ (void)addDeviceContextToEvent:(SentryEvent *)event fromPLCrashReport:(PLCrashReport *)report {
        NSMutableDictionary *deviceData = [NSMutableDictionary new];
        
#if TARGET_OS_OSX || TARGET_OS_MACCATALYST
        NSString *systemName = @"macOS";
#elif SENTRY_HAS_UIKIT
        NSString *systemName = [UIDevice currentDevice].systemName;
#elif TARGET_OS_WATCH
        NSString *systemName = @"watchOS";
#endif
    
// TODO
        NSString *family = [[systemName componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] firstObject];
//
        [deviceData setValue:family forKey:@"family"];
//

#if TARGET_OS_OSX || TARGET_OS_MACCATALYST
        // MacOS has the machine in the model field, and no model
        [deviceData setValue:[NSString stringWithUTF8String:sentry_stringSysctl("hw.model")] forKey:@"model"];
#else
        [deviceData setValue:[NSString stringWithUTF8String:sentry_stringSysctl("hw.machine")] forKey:@"model"];
        [deviceData setValue:[NSString stringWithUTF8String:sentry_stringSysctl("hw.model")] forKey:@"model_id"];
#endif
        [deviceData setValue:[NSNumber numberWithUnsignedLongLong:freeMemory()] forKey:@"free_memory"];
        [deviceData setValue:[NSNumber numberWithUnsignedLongLong:usableMemory()] forKey:@"usable_memory"];
        [deviceData setValue:[NSNumber numberWithUnsignedLongLong:sentry_uint64ForName("hw.memsize")] forKey:@"memory_size"];
        [deviceData setValue:[[[NSFileManager defaultManager] attributesOfFileSystemForPath:NSHomeDirectory() error:nil] objectForKey:NSFileSystemSize] forKey:@"storage_size"];
        

#if TARGET_OS_SIMULATOR
        [deviceData setValue:@(YES) forKey:@"simulator"];
#endif
    
    if (report.hasMachineInfo) {
        //    plCrashReport.hasMachineInfo
        //    plCrashReport.machineInfo.logicalProcessorCount 16
        //    plCrashReport.machineInfo.modelName x86_64 iPhone11,8
        //    plCrashReport.machineInfo.processorCount 8
        //    plCrashReport.machineInfo.processorInfo.type 7
        //    plCrashReport.machineInfo.processorInfo.subtype 8
        //    plCrashReport.machineInfo.processorInfo.typeEncoding PLCrashReportProcessorTypeEncodingMach
        
        [deviceData setValue:[NSNumber numberWithUnsignedLong:report.machineInfo.logicalProcessorCount] forKey:@"processor_logical_count"];
        [deviceData setValue:[NSNumber numberWithUnsignedLong:report.machineInfo.processorCount] forKey:@"processor_count"];
        [deviceData setValue:[NSNumber numberWithUnsignedLongLong:report.machineInfo.processorInfo.type] forKey:@"processor_type"];
        [deviceData setValue:[NSNumber numberWithUnsignedLongLong:report.machineInfo.processorInfo.subtype] forKey:@"processor_subtype"];
        
        const NXArchInfo* archInfo = NXGetLocalArchInfo();
        if (archInfo != NULL) {
            [deviceData setValue:[NSString stringWithUTF8String:archInfo->name] forKey:@"arch"];
        } else {
            const char* arch = sentry_getCPUArchForCPUType((int)report.machineInfo.processorInfo.type, (int)report.machineInfo.processorInfo.subtype);
            if (arch != NULL) {
                [deviceData setValue:[NSString stringWithUTF8String:arch] forKey:@"arch"];
            }
        }
    }
    
    if (report.hasProcessInfo) {
        //    if plCrashReport.hasProcessInfo
        //    plCrashReport.processInfo.native YES
        //    plCrashReport.processInfo.parentProcessID 26034
        //    plCrashReport.processInfo.parentProcessName launchd_sim
        //    plCrashReport.processInfo.processID 28672
        //    plCrashReport.processInfo.processName sentry-ios-cocoa
        //    plCrashReport.processInfo.processPath /Users/haza/Library/Developer/CoreSimulator/Devices/98089135-8D3D-43C7-970F-6D9B57FB3A0D/data/Containers/Bundle/Application/04B58277-52F4-4971-A934-05C24C24F94D/sentry-ios-cocoapods.app/sentry-ios-cocoapods
        //    plCrashReport.processInfo.processStartTime 2020-02-05 15:14:31 +0000
        [deviceData setValue:[report.processInfo.processStartTime sentry_toIso8601String] forKey:@"boot_time"];
        [deviceData setValue:[NSNumber numberWithUnsignedLong:report.processInfo.processID] forKey:@"process_id"];
        [deviceData setValue:report.processInfo.parentProcessName forKey:@"process_name"];
        [deviceData setValue:[NSNumber numberWithBool:report.processInfo.native] forKey:@"process_native"];
        [deviceData setValue:report.processInfo.processPath forKey:@"executable_path"];
    }
    [deviceData setValue:[NSTimeZone localTimeZone].abbreviation forKey:@"timezone"];
    
    if (event.context.deviceContext) {
        [deviceData addEntriesFromDictionary:event.context.deviceContext];
    }
    event.context.deviceContext = deviceData;
    
}

- (NSArray *)convertPLStackFrames:(NSArray *)stackFrames withBaseAddress:(uint64_t)baseAddress andSize:(uint64_t)size {
    NSMutableArray *frames = [NSMutableArray new];
    for (PLCrashReportStackFrameInfo *plFrame in stackFrames) {
        SentryFrame *frame = [[SentryFrame alloc] init];
        if (plFrame.symbolInfo.symbolName) {
            frame.function = plFrame.symbolInfo.symbolName;
        }
        frame.instructionAddress = hexAddress([NSNumber numberWithUnsignedLongLong:plFrame.instructionPointer]);
        frame.imageAddress = hexAddress([NSNumber numberWithUnsignedLongLong:plFrame.symbolInfo.startAddress]);
        frame.symbolAddress = hexAddress([NSNumber numberWithUnsignedLongLong:plFrame.symbolInfo.endAddress]);
        if (plFrame.symbolInfo.startAddress >= baseAddress && plFrame.symbolInfo.startAddress < baseAddress+size) {
            frame.inApp = @YES;
        }
        [frames addObject:frame];
    }
    return [frames reverseObjectEnumerator].allObjects;
}

- (SentryEvent *)convertPLCrashReportToEvent:(PLCrashReport *)plCrashReport {
    uint64_t baseAddress = 0;
    uint64_t size = 0;
    
    NSMutableArray<SentryDebugMeta *> *debugImages = [NSMutableArray new];
    for (PLCrashReportBinaryImageInfo *plImage in plCrashReport.images) {
        SentryDebugMeta *debugMeta = [[SentryDebugMeta alloc] init];
        debugMeta.uuid = plImage.imageUUID;
        debugMeta.type = @"apple";
        debugMeta.imageAddress = hexAddress([NSNumber numberWithUnsignedLongLong:plImage.imageBaseAddress]);
        if (baseAddress == 0) {
            baseAddress = plImage.imageBaseAddress;
        }
        debugMeta.imageSize = [NSNumber numberWithUnsignedLongLong:plImage.imageSize];
        if (size == 0) {
            size = plImage.imageSize;
        }
        debugMeta.name = plImage.imageName;
        [debugImages addObject:debugMeta];
    }
    
    SentryException *exception = [[SentryException alloc] initWithValue:@"Unknown Exception" type:@"Unknown Type"];
    
    SentryMechanism *mechanism = [[SentryMechanism alloc] initWithType:@""];
    mechanism.handled = @(NO);
    
    NSMutableDictionary *meta = [NSMutableDictionary new];
    if (nil != plCrashReport.machExceptionInfo) {
        NSMutableDictionary *machException = [NSMutableDictionary new];
        [machException setValue:[NSNumber numberWithUnsignedLongLong:plCrashReport.machExceptionInfo.type] forKey:@"exception"];
        [machException setValue:[plCrashReport.machExceptionInfo.codes lastObject] forKey:@"subcode"];
        [machException setValue:[plCrashReport.machExceptionInfo.codes firstObject] forKey:@"code"];
        [meta setValue:machException forKey:@"mach_exception"];
    }
    if (nil != plCrashReport.signalInfo && plCrashReport.signalInfo.code && plCrashReport.signalInfo.name) {
        NSMutableDictionary *signal = [NSMutableDictionary new];
        [signal setValue:hexAddress([NSNumber numberWithUnsignedLongLong:plCrashReport.signalInfo.address]) forKey:@"address"];
        [signal setValue:plCrashReport.signalInfo.code forKey:@"code_name"];
        [signal setValue:plCrashReport.signalInfo.name forKey:@"name"];
        [meta setValue:signal forKey:@"signal"];
    }
    
    mechanism.meta = meta;
    
    if (plCrashReport.signalInfo) {
        exception = [[SentryException alloc] initWithValue: [NSString stringWithFormat:@"%@ (%@)", plCrashReport.signalInfo.name, plCrashReport.signalInfo.code] type:plCrashReport.signalInfo.name];
    }
    
    if (plCrashReport.machExceptionInfo.type) {
        exception.type = [NSString stringWithUTF8String:sentry_plcrash_mach_exceptionName(plCrashReport.machExceptionInfo.type)];
        mechanism.type = @"mach";
    }
    
    if (plCrashReport.hasExceptionInfo) {
//        plCrashReport.uuidRef filter dupes
        
//        plCrashReport.exceptionInfo.stackFrames
        exception = [[SentryException alloc] initWithValue:plCrashReport.exceptionInfo.exceptionReason type:plCrashReport.exceptionInfo.exceptionName];
        SentryThread *exceptionThread = [[SentryThread alloc] initWithThreadId:@0];
        exceptionThread.stacktrace = [[SentryStacktrace alloc] initWithFrames:[self convertPLStackFrames:plCrashReport.exceptionInfo.stackFrames withBaseAddress:baseAddress andSize:size] registers:@{}];
        exception.thread = exceptionThread;
        mechanism.type = @"nsexception";
    }
    
    exception.mechanism = mechanism;

    NSMutableArray *threads = [NSMutableArray new];
    for (PLCrashReportThreadInfo *plThread in plCrashReport.threads) {
        SentryThread *thread = [[SentryThread alloc] initWithThreadId:[NSNumber numberWithLong:plThread.threadNumber]];

        NSArray *frames = [self convertPLStackFrames:plThread.stackFrames withBaseAddress:baseAddress andSize:size];
        
        NSMutableDictionary *registers = [NSMutableDictionary new];
        for (PLCrashReportRegisterInfo *plRegister in plThread.registers) {
            [registers setValue:hexAddress([NSNumber numberWithUnsignedLongLong:plRegister.registerValue]) forKey:plRegister.registerName];
        }
        SentryStacktrace *stacktrace = [[SentryStacktrace alloc] initWithFrames:frames registers:registers];
        thread.stacktrace = stacktrace;
        if (thread.stacktrace.frames.count == 0) {
            // If we don't have any frames, we discard the whole frame
            thread.stacktrace = nil;
        }
        thread.crashed = [NSNumber numberWithBool:plThread.crashed];
        if (plThread.crashed && exception.thread == nil) {
            exception.thread = thread;
        }
//            thread.current = [NSNumber numberWithBool:plThread.current];
//            thread.name
        [threads addObject:thread];
    }
    
    SentryEvent *event = [[SentryEvent alloc] initWithLevel:kSentrySeverityFatal];
    event.context = [[SentryContext alloc] init];
    
    [SentryCrashIntegration addOsContextToEvent:event fromPLCrashReport:plCrashReport];
    [SentryCrashIntegration addDeviceContextToEvent:event fromPLCrashReport:plCrashReport];
    [SentryCrashIntegration addAppContextToEvent:event fromPLCrashReport:plCrashReport];
//    if ([self.report[@"report"][@"timestamp"] isKindOfClass:NSNumber.class]) {
//        event.timestamp = [NSDate dateWithTimeIntervalSince1970:[self.report[@"report"][@"timestamp"] integerValue]];
//    } else {
//        event.timestamp = [NSDate sentry_fromIso8601String:self.report[@"report"][@"timestamp"]];
//    }
    event.debugMeta = debugImages;
    event.threads = threads;
    event.exceptions = @[exception];
    
//    event.releaseName = self.userContext[@"releaseName"];
//    event.dist = self.userContext[@"dist"];
//    event.environment = self.userContext[@"environment"];
    
    // We want to set the release and dist to the version from the crash report itself
    // otherwise it can happend that we have two different version when the app crashes
    // right before an app update #218 #219
//    if (nil == event.releaseName && event.context.appContext[@"app_identifier"] && event.context.appContext[@"app_version"]) {
//        event.releaseName = [NSString stringWithFormat:@"%@-%@", event.context.appContext[@"app_identifier"], event.context.appContext[@"app_version"]];
//    }
//    if (nil == event.dist && event.context.appContext[@"app_build"]) {
//        event.dist = event.context.appContext[@"app_build"];
//    }
//    event.extra = [self convertExtra];
//    event.tags = [self convertTags];
//    event.user = [self convertUser];
    return event;
}

@end
