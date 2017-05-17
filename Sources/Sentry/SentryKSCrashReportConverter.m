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
#import <Sentry/SentryDebugMeta.h>
#import <Sentry/SentryThread.h>
#import <Sentry/SentryStacktrace.h>
#import <Sentry/SentryFrame.h>
#import <Sentry/SentryException.h>

#else
#import "SentryKSCrashReportConverter.h"
#import "SentryEvent.h"
#import "SentryDebugMeta.h"
#import "SentryThread.h"
#import "SentryStacktrace.h"
#import "SentryFrame.h"
#import "SentryException.h"
#endif

@interface SentryKSCrashReportConverter ()

@property(nonatomic, strong) NSDictionary *report;
@property(nonatomic, assign) NSInteger crashedThreadIndex;
@property(nonatomic, strong) NSDictionary *exceptionContext;
@property(nonatomic, strong) NSArray *binaryImages;
@property(nonatomic, strong) NSArray *threads;
@property(nonatomic, strong) NSDictionary *systemContext;

@end

@implementation SentryKSCrashReportConverter

// TODO refactor
static inline NSString *hexAddress(NSNumber *value) {
    return [NSString stringWithFormat:@"0x%016llx", [value unsignedLongLongValue]];
}

- (instancetype)initWithReport:(NSDictionary *)report {
    self = [super init];
    if (self) {
        self.report = report;
        self.binaryImages = report[@"binary_images"];
        self.systemContext = report[@"system"];
        
        NSDictionary *crashContext;
        // This is an incomplete crash report
        if (nil != report[@"recrash_report"]) {
            crashContext = report[@"recrash_report"];
        } else {
            crashContext = report[@"crash"];
        }
        
        self.exceptionContext = crashContext[@"error"];
        self.threads = crashContext[@"threads"];
        for(NSUInteger i = 0; i < self.threads.count; i++) {
            NSDictionary *thread = self.threads[i];
            if (thread[@"crashed"]) {
                self.crashedThreadIndex = (NSInteger)i;
                break;
            }
        }
    }
    return self;
}

- (SentryEvent *)convertReportToEvent {
    SentryEvent *event = [[SentryEvent alloc] initWithLevel:kSentrySeverityDebug];
    event.debugMeta = [self convertDebugMeta];
    event.threads = [self convertThreads];
    event.exceptions = [self convertExceptions];
    return event;
}

//
//- (NSDictionary *)deviceContext {
//    NSMutableDictionary *result = [NSMutableDictionary new];
//    result[@"name"] = self.deviceName;
//    result[@"family"] = self.family;
//    result[@"model"] = self.model;
//    result[@"model_id"] = self.modelID;
//    result[@"arch"] = self.systemContext[@"cpu_arch"];
//    result[@"battery_level"] = self.batteryLevel;
//    result[@"orientation"] = self.orientation;
//    if ([self.systemContext valueForKeyPath:@"memory.free"]) {
//        long free_memory = [[self.systemContext valueForKeyPath:@"memory.free"] longValue];
//        result[@"free_memory"] = [NSByteCountFormatter stringFromByteCount:free_memory countStyle:NSByteCountFormatterCountStyleMemory];
//    }
//    if ([self.systemContext valueForKeyPath:@"memory.size"]) {
//        long memory_size = [[self.systemContext valueForKeyPath:@"memory.size"] longValue];
//        result[@"memory_size"] = [NSByteCountFormatter stringFromByteCount:memory_size countStyle:NSByteCountFormatterCountStyleMemory];
//    }
//    if (self.systemContext[@"storage"]) {
//        long storage_size = [self.systemContext[@"storage"] longValue];
//        result[@"storage_size"] = [NSByteCountFormatter stringFromByteCount:storage_size countStyle:NSByteCountFormatterCountStyleMemory];
//    }
//    if ([self.systemContext valueForKeyPath:@"memory.usable"]) {
//        long usable_memory = [[self.systemContext valueForKeyPath:@"memory.usable"] longValue];
//        result[@"usable_memory"] = [NSByteCountFormatter stringFromByteCount:usable_memory countStyle:NSByteCountFormatterCountStyleMemory];
//    }
//    return result;
//}
//
//- (NSDictionary *)osContext {
//    NSMutableDictionary *result = [NSMutableDictionary new];
//    result[@"name"] = self.systemContext[@"system_name"];
//    result[@"version"] = self.systemContext[@"system_version"];
//    result[@"build"] = self.systemContext[@"os_version"];
//    result[@"kernel_version"] = self.systemContext[@"kernel_version"];
//    result[@"rooted"] = self.systemContext[@"jailbroken"];
//    return result;
//}
//
//- (NSDictionary *)runtimeContext {
//    NSMutableDictionary *result = [NSMutableDictionary new];
//    result[@"name"] = self.systemContext[@"CFBundleName"];
//    result[@"version"] = self.systemContext[@"CFBundleVersion"];
//    return result;
//}
//
- (NSArray *)rawStackTraceForThreadIndex:(NSInteger)threadIndex {
    NSDictionary *thread = [self.threads objectAtIndex:threadIndex];
    return thread[@"backtrace"][@"contents"];
}

- (NSDictionary *)registersForThreadIndex:(NSInteger)threadIndex {
    NSDictionary *thread = [self.threads objectAtIndex:threadIndex];
    NSMutableDictionary *registers = [NSMutableDictionary new];
    for (NSString *key in [thread[@"registers"][@"basic"] allKeys]) {
        [registers setValue:hexAddress(thread[@"registers"][@"basic"][key]) forKey:key];
    }
    return registers;
}

- (NSDictionary *)binaryImageForAddress:(uintptr_t)address {
    for (NSDictionary *binaryImage in self.binaryImages) {
        uintptr_t imageStart = (uintptr_t) [binaryImage[@"image_addr"] unsignedLongLongValue];
        uintptr_t imageEnd = imageStart + (uintptr_t) [binaryImage[@"image_size"] unsignedLongLongValue];
        if (address >= imageStart && address < imageEnd) {
            return binaryImage;
        }
    }
    return nil;
}

- (SentryThread *)threadAtIndex:(NSInteger)threadIndex {
    NSDictionary *threadDictionary = [self.threads objectAtIndex:threadIndex];
    
    SentryThread *thread = [[SentryThread alloc] initWithThreadId:threadDictionary[@"index"]];
    thread.stacktrace = [self stackTraceForThreadIndex:threadIndex];
    thread.crashed = threadDictionary[@"crashed"];
    thread.current = threadDictionary[@"current_thread"];
    thread.name = threadDictionary[@"name"];
    if (nil == thread.name) {
        thread.name = threadDictionary[@"dispatch_queue"];
    }
    return thread;
}

- (SentryFrame *)stackFrameAtIndex:(NSInteger)frameIndex inThreadIndex:(NSInteger)threadIndex {
    NSDictionary *frameDictionary = [self rawStackTraceForThreadIndex:threadIndex][frameIndex];
    uintptr_t instructionAddress = (uintptr_t)[frameDictionary[@"instruction_addr"] unsignedLongLongValue];
    NSDictionary *binaryImage = [self binaryImageForAddress:instructionAddress];
//    BOOL isAppImage = [binaryImage[@"name"] containsString:@"/Bundle/Application/"];
    SentryFrame *frame = [[SentryFrame alloc] initWithSymbolAddress:hexAddress(frameDictionary[@"symbol_addr"])];
    frame.instructionAddress = hexAddress(frameDictionary[@"instruction_addr"]);
    frame.platform = @"cocoa";
    frame.imageAddress = hexAddress(binaryImage[@"image_addr"]);
    frame.package = binaryImage[@"name"];
    frame.function = frameDictionary[@"symbol_name"];
    return frame;
}

- (NSArray<SentryFrame *> *)stackFramesForThreadIndex:(NSInteger)threadIndex {
    NSUInteger frameCount = [self rawStackTraceForThreadIndex:threadIndex].count;
    if (frameCount <= 0) {
        return nil;
    }

    NSMutableArray *frames = [NSMutableArray arrayWithCapacity:frameCount];
    for (NSInteger i = frameCount - 1; i >= 0; i--) {
        [frames addObject:[self stackFrameAtIndex:i inThreadIndex:threadIndex]];
    }
    return frames;
}

- (SentryStacktrace *)stackTraceForThreadIndex:(NSInteger)threadIndex {
    NSArray<SentryFrame *> *frames = [self stackFramesForThreadIndex:threadIndex];
    if (frames == nil) {
        return nil;
    }
    return [[SentryStacktrace alloc] initWithFrames:frames
                                          registers:[self registersForThreadIndex:threadIndex]];
}

- (SentryThread *)crashedThread {
    return [self threadAtIndex:self.crashedThreadIndex];
}

- (NSArray<SentryDebugMeta *> *)convertDebugMeta {
    NSMutableArray<SentryDebugMeta *> *result = [NSMutableArray new];
    for (NSDictionary *sourceImage in self.report[@"binary_images"]) {
        SentryDebugMeta *debugMeta = [[SentryDebugMeta alloc] initWithUuid:sourceImage[@"uuid"]];
        debugMeta.type = @"apple";
        debugMeta.cpuType = sourceImage[@"cpu_type"];
        debugMeta.cpuSubType = sourceImage[@"cpu_subtype"];
        debugMeta.imageAddress = hexAddress(sourceImage[@"image_addr"]);
        debugMeta.imageSize = sourceImage[@"image_size"];
        debugMeta.imageVmAddress = hexAddress(sourceImage[@"image_vmaddr"]);
        debugMeta.name = sourceImage[@"name"];
        debugMeta.majorVersion = sourceImage[@"major_version"];
        debugMeta.minorVersion = sourceImage[@"minor_version"];
        debugMeta.revisionVersion = sourceImage[@"revision_version"];
        [result addObject:debugMeta];
    }
    return result;
}

- (NSArray<SentryException *> *)convertExceptions {
    NSString *exceptionType = self.exceptionContext[@"type"];
    SentryException *exception;
    if ([exceptionType isEqualToString:@"nsexception"]) {
        exception = [[SentryException alloc] initWithValue:self.exceptionContext[@"reason"]
                                                      type:self.exceptionContext[@"nsexception"][@"name"]];
    } else if ([exceptionType isEqualToString:@"cpp_exception"]) {
        exception = [[SentryException alloc] initWithValue:self.exceptionContext[@"reason"]
                                                      type:self.exceptionContext[@"cpp_exception"][@"name"]];
    } else if ([exceptionType isEqualToString:@"mach"]) {
        exception = [[SentryException alloc] initWithValue:[NSString stringWithFormat:@"Exception %@, Code %@, Subcode %@",
                                                            self.exceptionContext[@"mach"][@"exception"],
                                                            self.exceptionContext[@"mach"][@"code"],
                                                            self.exceptionContext[@"mach"][@"subcode"]]
                                                      type:self.exceptionContext[@"mach"][@"exception_name"]];
    } else if ([exceptionType isEqualToString:@"signal"]) {
        exception = [[SentryException alloc] initWithValue:[NSString stringWithFormat:@"Signal %@, Code %@",
                                                            self.exceptionContext[@"signal"][@"signal"],
                                                            self.exceptionContext[@"signal"][@"code"]]
                                                      type:self.exceptionContext[@"signal"][@"name"]];
    } else if ([exceptionType isEqualToString:@"user"]) {
        // TOOD
    }
    
    exception.mechanism = [self extractMechanism];
    exception.thread = [self crashedThread];
    
    return @[exception];
}

- (NSDictionary<NSString *, id> *)extractMechanism {
    NSMutableDictionary<NSString *, id> *mechanism = [NSMutableDictionary new];
    // This is important we want both signal an mach in mechanism
    if (nil != [self.exceptionContext objectForKey:@"signal"]) {
        NSMutableDictionary *content = [NSMutableDictionary new];
        [content setValue:self.exceptionContext[@"signal"][@"name"] forKey:@"name"];
        [content setValue:self.exceptionContext[@"signal"][@"signal"] forKey:@"signal"];
        [content setValue:self.exceptionContext[@"signal"][@"subcode"] forKey:@"subcode"];
        [content setValue:self.exceptionContext[@"signal"][@"code"] forKey:@"code"];
        [content setValue:self.exceptionContext[@"signal"][@"code_name"] forKey:@"code_name"];
        [mechanism setValue:content forKey:@"posix_signal"];
    }
    // This is important we want both signal an mach in mechanism
    if (nil != [self.exceptionContext objectForKey:@"mach"]) {
        NSMutableDictionary *content = [NSMutableDictionary new];
        [content setValue:self.exceptionContext[@"mach"][@"exception_name"] forKey:@"exception_name"];
        [content setValue:self.exceptionContext[@"mach"][@"exception"] forKey:@"exception"];
        [content setValue:self.exceptionContext[@"mach"][@"signal"] forKey:@"signal"];
        [content setValue:self.exceptionContext[@"mach"][@"subcode"] forKey:@"subcode"];
        [content setValue:self.exceptionContext[@"mach"][@"code"] forKey:@"code"];
        [mechanism setValue:content forKey:@"mach_exception"];
    }
    
    if (nil != self.exceptionContext[@"address"]) {
        [mechanism setValue:hexAddress(self.exceptionContext[@"address"]) forKey:@"relevant_address"];
    }

    return mechanism;
}

- (NSArray *)convertThreads {
    NSMutableArray *result = [NSMutableArray new];
    for (NSInteger threadIndex = 0; threadIndex < (NSInteger) self.threads.count; threadIndex++) {
        [result addObject:[self threadAtIndex:threadIndex]];
    }
    return result;
}

@end
