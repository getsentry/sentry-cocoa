//
//  SentryKSCrashReportConverter.m
//  Sentry
//
//  Created by Daniel Griesser on 10/05/2017.
//  Copyright © 2017 Sentry. All rights reserved.
//

#if __has_include(<Sentry/Sentry.h>)

#import <Sentry/SentryKSCrashReportConverter.h>
#import <Sentry/SentryEvent.h>

#else
#import "SentryKSCrashReportConverter.h"
#import "SentryEvent.h"
#endif

@interface SentryKSCrashReportConverter ()

@property(nonatomic, strong) NSDictionary *report;
@property(nonatomic, assign) NSInteger crashedThreadIndex;
@property(nonatomic, strong) NSDictionary *exceptionContext;
@property(nonatomic, strong) NSArray *binaryImages;
@property(nonatomic, strong) NSArray *threads;
@property(nonatomic, strong) NSDictionary *systemContext;
@property(nonatomic, strong) NSDictionary *reportContext;
@property(nonatomic, copy) NSString *platform;

@end

@implementation SentryKSCrashReportConverter

static inline NSString *hexAddress(NSNumber *value) {
    return [NSString stringWithFormat:@"0x%016llx", value.unsignedLongLongValue];
}

- (instancetype)initWithReport:(NSDictionary *)report {
    self = [super init];
    if (self) {
        self.report = report;
//        self.platform = @"cocoa";
//        self.binaryImages = report[@"binary_images"];
//        self.systemContext = report[@"system"];
//        self.reportContext = report[@"report"];
//        NSDictionary *crashContext = report[@"crash"];
//        self.exceptionContext = crashContext[@"error"];
//        self.threads = crashContext[@"threads"];
//        for(NSUInteger i = 0; i < self.threads.count; i++)
//        {
//            NSDictionary *thread = self.threads[i];
//            if(thread[@"crashed"])
//            {
//                self.crashedThreadIndex = (NSInteger)i;
//                break;
//            }
//        }
    }
    return self;
}

- (SentryEvent *)event {
    // TODO return converted Report
    return [[SentryEvent alloc] initWithMessage:@"test" timestamp:[NSDate date] level:kSentrySeverityDebug];
}

// TODO not needed
- (BOOL)isCustomReport {
    NSString *reportType = [self.report valueForKeyPath:@"report.type"];
    return [reportType isEqualToString:@"custom"];
}

- (NSString *)deviceName {
    return nil; // TODO
}

- (NSString *)family {
    NSString *systemName = self.systemContext[@"system_name"];
    NSArray *components = [systemName componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    return components[0];
}

- (NSString *)model {
    return self.systemContext[@"machine"];
}

- (NSString *)modelID {
    return self.systemContext[@"model"];
}

- (NSString *)batteryLevel {
    return nil; // Not recording this yet
}

- (NSString *)orientation {
    return nil; // Not recording this yet
}

- (NSDictionary *)deviceContext {
    NSMutableDictionary *result = [NSMutableDictionary new];
    result[@"name"] = self.deviceName;
    result[@"family"] = self.family;
    result[@"model"] = self.model;
    result[@"model_id"] = self.modelID;
    result[@"arch"] = self.systemContext[@"cpu_arch"];
    result[@"battery_level"] = self.batteryLevel;
    result[@"orientation"] = self.orientation;
    if ([self.systemContext valueForKeyPath:@"memory.free"]) {
        long free_memory = [[self.systemContext valueForKeyPath:@"memory.free"] longValue];
        result[@"free_memory"] = [NSByteCountFormatter stringFromByteCount:free_memory countStyle:NSByteCountFormatterCountStyleMemory];
    }
    if ([self.systemContext valueForKeyPath:@"memory.size"]) {
        long memory_size = [[self.systemContext valueForKeyPath:@"memory.size"] longValue];
        result[@"memory_size"] = [NSByteCountFormatter stringFromByteCount:memory_size countStyle:NSByteCountFormatterCountStyleMemory];
    }
    if (self.systemContext[@"storage"]) {
        long storage_size = [self.systemContext[@"storage"] longValue];
        result[@"storage_size"] = [NSByteCountFormatter stringFromByteCount:storage_size countStyle:NSByteCountFormatterCountStyleMemory];
    }
    if ([self.systemContext valueForKeyPath:@"memory.usable"]) {
        long usable_memory = [[self.systemContext valueForKeyPath:@"memory.usable"] longValue];
        result[@"usable_memory"] = [NSByteCountFormatter stringFromByteCount:usable_memory countStyle:NSByteCountFormatterCountStyleMemory];
    }
    return result;
}

- (NSDictionary *)osContext {
    NSMutableDictionary *result = [NSMutableDictionary new];
    result[@"name"] = self.systemContext[@"system_name"];
    result[@"version"] = self.systemContext[@"system_version"];
    result[@"build"] = self.systemContext[@"os_version"];
    result[@"kernel_version"] = self.systemContext[@"kernel_version"];
    result[@"rooted"] = self.systemContext[@"jailbroken"];
    return result;
}

- (NSDictionary *)runtimeContext {
    NSMutableDictionary *result = [NSMutableDictionary new];
    result[@"name"] = self.systemContext[@"CFBundleName"];
    result[@"version"] = self.systemContext[@"CFBundleVersion"];
    return result;
}

- (NSArray *)rawStackTraceForThreadIndex:(NSInteger)threadIndex {
    NSDictionary *thread = self.threads[(NSUInteger) threadIndex];
    return thread[@"backtrace"][@"contents"];
}

- (NSDictionary *)registersForThreadIndex:(NSInteger)threadIndex {
    NSDictionary *thread = self.threads[(NSUInteger) threadIndex];
    return thread[@"registers"][@"basic"];
}

- (NSDictionary *)binaryImageForAddress:(uintptr_t)address {
    for (NSDictionary *binaryImage in self.binaryImages) {
        uintptr_t
                imageStart = (uintptr_t)
        [binaryImage[@"image_addr"] unsignedLongLongValue];
        uintptr_t
                imageEnd = imageStart + (uintptr_t)
        [binaryImage[@"image_size"] unsignedLongLongValue];
        if (address >= imageStart && address < imageEnd) {
            return binaryImage;
        }
    }
    return nil;
}

- (NSDictionary *)threadAtIndex:(NSInteger)threadIndex includeStacktrace:(BOOL)includeStacktrace {
    NSMutableDictionary *result = [NSMutableDictionary new];
    NSDictionary *thread = self.threads[(NSUInteger) threadIndex];
    if (includeStacktrace) {
        result[@"stacktrace"] = [self stackTraceForThreadIndex:threadIndex showRegisters:YES];
    }
    result[@"id"] = thread[@"index"];
    result[@"crashed"] = thread[@"crashed"];
    result[@"current"] = thread[@"current_thread"];
    result[@"name"] = thread[@"name"];
    if (!result[@"name"]) {
        result[@"name"] = thread[@"dispatch_queue"];
    }
    return result;
}

- (NSDictionary *)stackFrameAtIndex:(NSInteger)frameIndex inThreadIndex:(NSInteger)threadIndex {
    NSDictionary *frame = [self rawStackTraceForThreadIndex:threadIndex][(NSUInteger) frameIndex];
    uintptr_t
            instructionAddress = (uintptr_t)
    [frame[@"instruction_addr"] unsignedLongLongValue];
    NSDictionary *binaryImage = [self binaryImageForAddress:instructionAddress];
    BOOL isAppImage = [binaryImage[@"name"] containsString:@"/Bundle/Application/"];
    NSString *function = frame[@"symbol_name"];
    if (function == nil) {
        function = @"<redacted>";
    }
    NSMutableDictionary *result = [NSMutableDictionary new];
    result[@"function"] = function;
    result[@"package"] = binaryImage[@"name"];
    result[@"image_addr"] = hexAddress(binaryImage[@"image_addr"]);
    result[@"platform"] = self.platform;
    result[@"instruction_addr"] = hexAddress(frame[@"instruction_addr"]);
    result[@"symbol_addr"] = hexAddress(frame[@"symbol_addr"]);
    result[@"in_app"] = [NSNumber numberWithBool:isAppImage];

    return result;
}

- (NSMutableArray *)stackFramesForThreadIndex:(NSInteger)threadIndex {
    int frameCount = (int) [self rawStackTraceForThreadIndex:threadIndex].count;
    if (frameCount <= 0) {
        return nil;
    }

    NSMutableArray *frames = [NSMutableArray arrayWithCapacity:(NSUInteger) frameCount];
    for (NSInteger i = frameCount - 1; i >= 0; i--) {
        [frames addObject:[self stackFrameAtIndex:i inThreadIndex:threadIndex]];
    }
    return frames;
}

- (NSDictionary *)stackTraceForThreadIndex:(NSInteger)threadIndex showRegisters:(BOOL)showRegisters {
    NSArray *frames = [self stackFramesForThreadIndex:threadIndex];
    if (frames == nil) {
        return nil;
    }
    NSMutableDictionary *result = [NSMutableDictionary new];
    result[@"frames"] = frames;
    int skipped = (int) [self.threads[(NSUInteger) threadIndex][@"backtrace"][@"skipped"] integerValue];
    if (skipped > 0) {
        result[@"frames_omitted"] = @[@"1", [NSString stringWithFormat:@"%d", skipped + 1]];
    }

    if (showRegisters) {
        result[@"registers"] = [self registersForThreadIndex:threadIndex];
    }

    return result;
}

- (NSDictionary *)crashedThread {
    return self.threads[(NSUInteger) self.crashedThreadIndex];
}

- (NSArray *)images {
    NSMutableArray *result = [NSMutableArray new];
    for (NSDictionary *sourceImage in self.binaryImages) {
        NSMutableDictionary *image = [NSMutableDictionary new];
        image[@"type"] = @"apple";
        image[@"cpu_type"] = sourceImage[@"cpu_type"];
        image[@"cpu_subtype"] = sourceImage[@"cpu_subtype"];
        image[@"image_addr"] = hexAddress(sourceImage[@"image_addr"]);
        image[@"image_size"] = sourceImage[@"image_size"];
        image[@"image_vmaddr"] = hexAddress(sourceImage[@"image_vmaddr"]);
        image[@"name"] = sourceImage[@"name"];
        image[@"uuid"] = sourceImage[@"uuid"];
        [result addObject:image];
    }
    return result;
}

- (NSDictionary *)makeExceptionInterfaceWithType:(NSString *)type
                                           value:(NSString *)value
                                      stackTrace:(NSDictionary *)stackTrace {
    NSMutableDictionary *result = [NSMutableDictionary new];
    result[@"type"] = type;
    result[@"value"] = value;
    result[@"stacktrace"] = stackTrace;
    result[@"thread_id"] = self.crashedThread[@"index"];
    return @{@"values": @[result]};
}

- (NSDictionary *)exceptionInterface {
    return nil;
}

- (NSArray *)threadsInterface {
    NSMutableArray *result = [NSMutableArray new];
    for (NSInteger threadIndex = 0; threadIndex < (NSInteger) self.threads.count; threadIndex++) {
        BOOL includeStacktrace = threadIndex != self.crashedThreadIndex;
        [result addObject:[self threadAtIndex:threadIndex includeStacktrace:includeStacktrace]];
    }
    return result;
}

@end
