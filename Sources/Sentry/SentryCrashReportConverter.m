#import "SentryCrashReportConverter.h"
#import "SentryBreadcrumb+Private.h"
#import "SentryBreadcrumb.h"
#import "SentryCrashStackCursor.h"
#import "SentryDateUtils.h"
#import "SentryDebugMeta.h"
#import "SentryEvent.h"
#import "SentryException.h"
#import "SentryFormatter.h"
#import "SentryFrame.h"
#import "SentryInternalDefines.h"
#import "SentryLogC.h"
#import "SentryMechanism.h"
#import "SentryMechanismContext.h"
#import "SentryStacktrace.h"
#import "SentrySwift.h"
#import "SentryThread.h"
#import "SentryUser.h"

@interface SentryCrashReportConverter ()

@property (nonatomic, strong) NSDictionary *report;
@property (nonatomic, assign) NSInteger crashedThreadIndex;
@property (nonatomic, strong) NSDictionary *exceptionContext;
@property (nonatomic, strong) NSArray *binaryImages;
@property (nonatomic, strong) NSArray *threads;
@property (nonatomic, strong) NSDictionary *systemContext;
@property (nonatomic, strong) NSDictionary *applicationStats;
@property (nonatomic, strong) NSString *diagnosis;
@property (nonatomic, strong) SentryInAppLogic *inAppLogic;

@end

@implementation SentryCrashReportConverter

- (instancetype)initWithReport:(NSDictionary *)report inAppLogic:(SentryInAppLogic *)inAppLogic
{
    self = [super init];
    if (self) {
        self.report = report;
        self.inAppLogic = inAppLogic;

        NSDictionary *userContextUnMerged = report[@"user"];
        if (userContextUnMerged == nil) {
            userContextUnMerged = [NSDictionary new];
        }

        // The SentryCrashIntegration used userInfo to put in scope data. This had a few downsides.
        // Now sentry_sdk_scope contains scope data. To be backwards compatible, to still support
        // data from userInfo, and to not have to do many changes in here we merge both dictionaries
        // here. For more details please check out SentryCrashScopeObserver.
        NSMutableDictionary *userContextMerged =
            [[NSMutableDictionary alloc] initWithDictionary:userContextUnMerged];
        [userContextMerged addEntriesFromDictionary:report[@"sentry_sdk_scope"] ?: @{}];
        [userContextMerged removeObjectForKey:@"sentry_sdk_scope"];
        self.userContext = userContextMerged;

        NSDictionary *crashContext;
        // This is an incomplete crash report
        if (nil != report[@"recrash_report"][@"crash"]) {
            crashContext = report[@"recrash_report"][@"crash"];
        } else {
            crashContext = report[@"crash"];
        }

        if (nil != report[@"recrash_report"][@"binary_images"]) {
            self.binaryImages = report[@"recrash_report"][@"binary_images"];
        } else {
            self.binaryImages = report[@"binary_images"];
        }

        self.diagnosis = crashContext[@"diagnosis"];
        self.exceptionContext = crashContext[@"error"];
        [self initThreads:crashContext[@"threads"]];

        self.systemContext = report[@"system"];
        if (self.systemContext[@"application_stats"] != nil) {
            self.applicationStats = self.systemContext[@"application_stats"];
        }
    }
    return self;
}

- (void)initThreads:(NSArray<NSDictionary *> *)threads
{
    if (nil != threads && [threads isKindOfClass:[NSArray class]]) {
        // SentryCrash sometimes produces recrash_reports where an element of threads is a
        // NSString instead of a NSDictionary. When this happens we can't read the details of
        // the thread, but we have to discard it. Otherwise we would crash.
        NSPredicate *onlyNSDictionary = [NSPredicate predicateWithBlock:^BOOL(id object,
            NSDictionary *bindings) { return [object isKindOfClass:[NSDictionary class]]; }];
        self.threads = [threads filteredArrayUsingPredicate:onlyNSDictionary];

        for (NSUInteger i = 0; i < self.threads.count; i++) {
            NSDictionary *thread = self.threads[i];
            if ([thread[@"crashed"] boolValue]) {
                self.crashedThreadIndex = (NSInteger)i;
                break;
            }
        }
    }
}

- (SentryEvent *_Nullable)convertReportToEvent
{
    @try {
        SentryEvent *event = [[SentryEvent alloc] initWithLevel:kSentryLevelFatal];
        if ([self.report[@"report"][@"timestamp"] isKindOfClass:NSNumber.class]) {
            event.timestamp = [NSDate
                dateWithTimeIntervalSince1970:[self.report[@"report"][@"timestamp"] integerValue]];
        } else if ([self.report[@"report"][@"timestamp"] isKindOfClass:NSString.class]) {
            event.timestamp = sentry_fromIso8601String(
                SENTRY_UNWRAP_NULLABLE(NSString, self.report[@"report"][@"timestamp"]));
        }
        event.threads = [self convertThreads];
        event.debugMeta = [self debugMetaForThreads:event.threads];
        event.exceptions = [self convertExceptions];

        event.dist = self.userContext[@"dist"];
        event.environment = self.userContext[@"environment"];

        NSMutableDictionary *mutableContext =
            [[NSMutableDictionary alloc] initWithDictionary:self.userContext[@"context"] ?: @{}];
        if (self.userContext[@"traceContext"]) {
            mutableContext[@"trace"] = self.userContext[@"traceContext"];
        }

        NSMutableDictionary *appContext;
        if (mutableContext[@"app"] != nil) {
            appContext = [mutableContext[@"app"] mutableCopy];
        } else {
            appContext = [NSMutableDictionary new];
        }
        appContext[@"in_foreground"] = self.applicationStats[@"application_in_foreground"];
        mutableContext[@"app"] = appContext;
        event.context = mutableContext;

        event.extra = self.userContext[@"extra"];
        event.tags = self.userContext[@"tags"];
        //    event.level we do not set the level here since this always resulted
        //    from a fatal crash

        event.user = [self convertUser];
        event.breadcrumbs = [self convertBreadcrumbs];

        // The releaseName must be set on the userInfo of SentryCrash.sharedInstance
        event.releaseName = self.userContext[@"release"];

        // We want to set the release and dist to the version from the crash report
        // itself otherwise it can happend that we have two different version when
        // the app crashes right before an app update #218 #219
        if (nil == event.releaseName && appContext[@"app_identifier"] && appContext[@"app_version"]
            && appContext[@"app_build"]) {
            event.releaseName =
                [NSString stringWithFormat:@"%@@%@+%@", appContext[@"app_identifier"],
                    appContext[@"app_version"], appContext[@"app_build"]];
        }

        if (nil == event.dist && appContext[@"app_build"]) {
            event.dist = appContext[@"app_build"];
        }

        return event;
    } @catch (NSException *exception) {
        SENTRY_LOG_ERROR(@"Could not convert report:%@", exception.description);
    }
    return nil;
}

- (SentryUser *_Nullable)convertUser
{
    SentryUser *user = nil;
    if (nil != self.userContext[@"user"]) {
        NSDictionary *storedUser = self.userContext[@"user"];
        user = [[SentryUser alloc] init];
        user.userId = storedUser[@"id"];
        user.email = storedUser[@"email"];
        user.username = storedUser[@"username"];
        user.data = storedUser[@"data"];
    }
    return user;
}

- (NSMutableArray<SentryBreadcrumb *> *)convertBreadcrumbs
{
    NSMutableArray *breadcrumbs = [NSMutableArray new];
    if (nil != self.userContext[@"breadcrumbs"]) {
        NSArray *storedBreadcrumbs = self.userContext[@"breadcrumbs"];
        for (NSDictionary *storedCrumb in storedBreadcrumbs) {
            SentryBreadcrumb *crumb = [[SentryBreadcrumb alloc]
                initWithLevel:[self sentryLevelFromString:storedCrumb[@"level"]]
                     category:storedCrumb[@"category"]
                    ?: @"default"]; // The default value is the same as the one in
                                    // SentryBreadcrumb.init
            crumb.message = storedCrumb[@"message"];
            crumb.type = storedCrumb[@"type"];
            crumb.origin = storedCrumb[@"origin"];
            if ([storedCrumb[@"timestamp"] isKindOfClass:NSString.class]) {
                crumb.timestamp = sentry_fromIso8601String(
                    SENTRY_UNWRAP_NULLABLE(NSString, storedCrumb[@"timestamp"]));
            }
            crumb.data = storedCrumb[@"data"];
            [breadcrumbs addObject:crumb];
        }
    }
    return breadcrumbs;
}

- (SentryLevel)sentryLevelFromString:(NSString *)level
{
    if ([level isEqualToString:@"fatal"]) {
        return kSentryLevelFatal;
    } else if ([level isEqualToString:@"warning"]) {
        return kSentryLevelWarning;
    } else if ([level isEqualToString:@"info"] || [level isEqualToString:@"log"]) {
        return kSentryLevelInfo;
    } else if ([level isEqualToString:@"debug"]) {
        return kSentryLevelDebug;
    } else if ([level isEqualToString:@"error"]) {
        return kSentryLevelError;
    }
    return kSentryLevelError;
}

- (NSArray *)rawStackTraceForThreadIndex:(NSInteger)threadIndex
{
    NSDictionary *thread = self.threads[threadIndex];
    return thread[@"backtrace"][@"contents"];
}

- (NSDictionary *)registersForThreadIndex:(NSInteger)threadIndex
{
    NSDictionary *thread = self.threads[threadIndex];
    NSMutableDictionary *registers = [NSMutableDictionary new];
    for (NSString *key in [thread[@"registers"][@"basic"] allKeys]) {
        [registers setValue:sentry_formatHexAddress(thread[@"registers"][@"basic"][key])
                     forKey:key];
    }
    return registers;
}

- (NSDictionary *)binaryImageForAddress:(uintptr_t)address
{
    NSDictionary *result = nil;
    for (NSDictionary *binaryImage in self.binaryImages) {
        uintptr_t imageStart = (uintptr_t)[binaryImage[@"image_addr"] unsignedLongLongValue];
        uintptr_t imageEnd
            = imageStart + (uintptr_t)[binaryImage[@"image_size"] unsignedLongLongValue];
        if (address >= imageStart && address < imageEnd) {
            result = binaryImage;
            break;
        }
    }
    return result;
}

/**
 * Creates a SentryThread from crash report thread data at the specified index.
 *
 * This method includes defensive null handling to prevent crashes when processing
 * malformed crash reports. The original bug was that invalid thread index types
 * could cause crashes when accessing threadId.intValue for isMain calculation.
 */
- (SentryThread *_Nullable)threadAtIndex:(NSInteger)threadIndex
{
    if (threadIndex >= [self.threads count]) {
        return nil;
    }
    NSDictionary *threadDictionary = self.threads[threadIndex];

    // Thread index validation: We must support nil/missing indexes for backward compatibility
    // with recrash reports (see testRecrashReport_WithThreadIsStringInsteadOfDict), but we
    // must reject invalid types when present to prevent crashes from calling .intValue on
    // non-NSNumber objects. This fixes a bug where malformed crash reports could cause
    // crashes in the converter itself when accessing threadId.intValue for isMain calculation.
    id threadIndexObj = threadDictionary[@"index"];
    if (threadIndexObj != nil && ![threadIndexObj isKindOfClass:[NSNumber class]]) {
        SENTRY_LOG_ERROR(@"Thread index is not a number: %@", threadIndexObj);
        return nil;
    }
    SentryThread *thread =
        [[SentryThread alloc] initWithThreadId:SENTRY_UNWRAP_NULLABLE(NSNumber, threadIndexObj)];
    // We only want to add the stacktrace if this thread hasn't crashed
    thread.stacktrace = [self stackTraceForThreadIndex:threadIndex];
    if (thread.stacktrace.frames.count == 0) {
        // If we don't have any frames, we discard the whole frame
        thread.stacktrace = nil;
    }
    thread.crashed = threadDictionary[@"crashed"];
    thread.current = threadDictionary[@"current_thread"];
    thread.name = threadDictionary[@"name"];
    // We don't have access to the MachineContextWrapper but we know first thread is always the main
    // Use null-safe check: threadIndexObj can be nil for recrash reports, and calling intValue on
    // a nil NSNumber would return 0, incorrectly marking threads without indexes as main threads.
    thread.isMain =
        [NSNumber numberWithBool:threadIndexObj != nil && [threadIndexObj intValue] == 0];
    if (nil == thread.name) {
        thread.name = threadDictionary[@"dispatch_queue"];
    }
    return thread;
}

- (SentryFrame *)stackFrameAtIndex:(NSInteger)frameIndex inThreadIndex:(NSInteger)threadIndex
{
    NSDictionary *frameDictionary = [self rawStackTraceForThreadIndex:threadIndex][frameIndex];
    uintptr_t instructionAddress
        = (uintptr_t)[frameDictionary[@"instruction_addr"] unsignedLongLongValue];
    NSDictionary *binaryImage = [self binaryImageForAddress:instructionAddress];
    SentryFrame *frame = [[SentryFrame alloc] init];
    // The symbol address is not known, so it defaults to 0
    frame.symbolAddress = @"0x0000000000000000";
    frame.instructionAddress = sentry_formatHexAddress(frameDictionary[@"instruction_addr"]);
    frame.imageAddress = sentry_formatHexAddress(binaryImage[@"image_addr"]);
    frame.package = binaryImage[@"name"];
    BOOL isInApp = [self.inAppLogic isInApp:binaryImage[@"name"]];
    frame.inApp = @(isInApp);
    return frame;
}

// We already get all the frames in the right order
- (NSArray<SentryFrame *> *)stackFramesForThreadIndex:(NSInteger)threadIndex
{
    NSUInteger frameCount = [self rawStackTraceForThreadIndex:threadIndex].count;
    if (frameCount <= 0) {
        return [NSArray new];
    }

    NSMutableArray *frames = [NSMutableArray arrayWithCapacity:frameCount];
    SentryFrame *lastFrame = nil;

    for (NSInteger i = 0; i < frameCount; i++) {
        NSDictionary *frameDictionary = [self rawStackTraceForThreadIndex:threadIndex][i];
        uintptr_t instructionAddress
            = (uintptr_t)[frameDictionary[@"instruction_addr"] unsignedLongLongValue];
        if (instructionAddress == SentryCrashSC_ASYNC_MARKER) {
            if (lastFrame != nil) {
                lastFrame.stackStart = @(YES);
            }
            // skip the marker frame
            continue;
        }
        lastFrame = [self stackFrameAtIndex:i inThreadIndex:threadIndex];
        [frames addObject:lastFrame];
    }

    return [[frames reverseObjectEnumerator] allObjects];
}

- (SentryStacktrace *)stackTraceForThreadIndex:(NSInteger)threadIndex
{
    NSArray<SentryFrame *> *frames = [self stackFramesForThreadIndex:threadIndex];
    SentryStacktrace *stacktrace =
        [[SentryStacktrace alloc] initWithFrames:frames
                                       registers:[self registersForThreadIndex:threadIndex]];
    [stacktrace fixDuplicateFrames];
    return stacktrace;
}

- (SentryThread *_Nullable)crashedThread
{
    return [self threadAtIndex:self.crashedThreadIndex];
}

- (SentryDebugMeta *)debugMetaFromBinaryImageDictionary:(NSDictionary *)sourceImage
{
    SentryDebugMeta *debugMeta = [[SentryDebugMeta alloc] init];
    debugMeta.debugID = sourceImage[@"uuid"];
    debugMeta.type = SentryDebugImageType;
    // We default to 0 on the server if not sent
    if ([sourceImage[@"image_vmaddr"] integerValue] > 0) {
        debugMeta.imageVmAddress = sentry_formatHexAddress(sourceImage[@"image_vmaddr"]);
    }
    debugMeta.imageAddress = sentry_formatHexAddress(sourceImage[@"image_addr"]);
    debugMeta.imageSize = sourceImage[@"image_size"];
    debugMeta.codeFile = sourceImage[@"name"];
    return debugMeta;
}

- (NSArray<SentryDebugMeta *> *)debugMetaForThreads:(NSArray<SentryThread *> *)threads
{
    NSMutableSet<NSString *> *imageNames = [[NSMutableSet alloc] init];

    for (SentryThread *thread in threads) {
        for (SentryFrame *frame in thread.stacktrace.frames) {
            NSString *_Nullable nullableImageAddress = frame.imageAddress;
            if (nullableImageAddress == nil) {
                continue;
            }
            [imageNames addObject:SENTRY_UNWRAP_NULLABLE(NSString, nullableImageAddress)];
        }
    }

    NSMutableArray<SentryDebugMeta *> *result = [NSMutableArray new];

    for (NSDictionary *sourceImage in self.binaryImages) {
        if ([imageNames containsObject:sentry_formatHexAddress(sourceImage[@"image_addr"])]) {
            [result addObject:[self debugMetaFromBinaryImageDictionary:sourceImage]];
        }
    }

    return result;
}

- (NSArray<SentryException *> *_Nullable)convertExceptions
{
    if (nil == self.exceptionContext) {
        return nil;
    }
    NSString *const exceptionType = self.exceptionContext[@"type"] ?: @"Unknown Exception";
    SentryException *exception = nil;
    if ([exceptionType isEqualToString:@"nsexception"]) {
        exception = [self parseNSException];
    } else if ([exceptionType isEqualToString:@"cpp_exception"]) {

        NSString *cppExceptionName = self.exceptionContext[@"cpp_exception"][@"name"];
        NSString *cppExceptionReason = self.exceptionContext[@"reason"];

        NSString *exceptionValue =
            [NSString stringWithFormat:@"%@: %@", cppExceptionName, cppExceptionReason];

        exception = [[SentryException alloc] initWithValue:exceptionValue type:@"C++ Exception"];

    } else if ([exceptionType isEqualToString:@"mach"]) {
        exception = [[SentryException alloc]
            initWithValue:[NSString stringWithFormat:@"Exception %@, Code %@, Subcode %@",
                              self.exceptionContext[@"mach"][@"exception"],
                              self.exceptionContext[@"mach"][@"code"],
                              self.exceptionContext[@"mach"][@"subcode"]]
                     type:self.exceptionContext[@"mach"][@"exception_name"]
                ?: @"Mach Exception"]; // The fallback value is best-attempt in case the exception
                                       // name is not available
    } else if ([exceptionType isEqualToString:@"signal"]) {
        exception =
            [[SentryException alloc] initWithValue:[NSString stringWithFormat:@"Signal %@, Code %@",
                                                       self.exceptionContext[@"signal"][@"signal"],
                                                       self.exceptionContext[@"signal"][@"code"]]
                                              type:self.exceptionContext[@"signal"][@"name"]
                    ?: @"Signal Exception"]; // The fallback value is best-attempt in case the
                                             // exception name is not available
    } else if ([exceptionType isEqualToString:@"user"]) {
        NSString *exceptionReason =
            [NSString stringWithFormat:@"%@", self.exceptionContext[@"reason"]];
        exception =
            [[SentryException alloc] initWithValue:exceptionReason
                                              type:self.exceptionContext[@"user_reported"][@"name"]
                    ?: @"User Reported Exception"]; // The fallback value is best-attempt in case
                                                    // the exception name is not available

        NSRange match = [exceptionReason rangeOfString:@":"];
        if (match.location != NSNotFound) {
            exception = [[SentryException alloc]
                initWithValue:[[exceptionReason
                                  substringWithRange:NSMakeRange(match.location + match.length,
                                                         (exceptionReason.length - match.location)
                                                             - match.length)]
                                  stringByTrimmingCharactersInSet:[NSCharacterSet
                                                                      whitespaceCharacterSet]]
                         type:[exceptionReason substringWithRange:NSMakeRange(0, match.location)]];
        }
    } else {
        exception = [[SentryException alloc] initWithValue:@"Unknown Exception" type:exceptionType];
    }

    [self enhanceValueFromNotableAddresses:exception];
    [self enhanceValueFromCrashInfoMessage:exception];
    exception.mechanism = [self extractMechanismOfType:exceptionType];

    SentryThread *crashedThread = [self crashedThread];
    exception.threadId = crashedThread.threadId;
    exception.stacktrace = crashedThread.stacktrace;

    NSString *exceptionValue = exception.value;
    if (nil != self.diagnosis && self.diagnosis.length > 0 && exceptionValue != nil
        && ![self.diagnosis containsString:exceptionValue]) {
        exception.value = [exceptionValue
            stringByAppendingString:[NSString stringWithFormat:@" >\n%@", self.diagnosis]];
    }
    return @[ exception ];
}

- (SentryException *)parseNSException
{
    NSString *reason = nil;
    if (self.exceptionContext[@"nsexception"][@"reason"] != nil) {
        reason = self.exceptionContext[@"nsexception"][@"reason"];
    } else if (self.exceptionContext[@"reason"] != nil) {
        reason = self.exceptionContext[@"reason"];
    }

    // The fallback value is best-attempt in case the exception name is not available
    NSString *type = self.exceptionContext[@"nsexception"][@"name"] ?: @"NSException";

    return [[SentryException alloc] initWithValue:reason type:type];
}

- (void)enhanceValueFromNotableAddresses:(SentryException *)exception
{
    // Gatekeeper fixes https://github.com/getsentry/sentry-cocoa/issues/231
    if ([self.threads count] == 0 || self.crashedThreadIndex >= [self.threads count]) {
        return;
    }
    NSDictionary *crashedThread = self.threads[self.crashedThreadIndex];
    NSDictionary *_Nullable notableAddresses = crashedThread[@"notable_addresses"];
    NSMutableOrderedSet *reasons = [[NSMutableOrderedSet alloc] init];
    if (nil != notableAddresses) {
        for (id key in notableAddresses) {
            NSDictionary *content = notableAddresses[key];
            if ([content[@"type"] isEqualToString:@"string"] && nil != content[@"value"]) {
                // if there are less than 3 slashes it shouldn't be a filepath
                if ([[content[@"value"] componentsSeparatedByString:@"/"] count] < 3) {
                    [reasons addObject:SENTRY_UNWRAP_NULLABLE(NSString, content[@"value"])];
                }
            }
        }
    }
    if (reasons.count > 0) {
        exception.value = [[[reasons array] sortedArrayUsingSelector:@selector
            (localizedCaseInsensitiveCompare:)] componentsJoinedByString:@" > "];
    }
}

- (void)enhanceValueFromCrashInfoMessage:(SentryException *)exception
{
    NSMutableArray<NSString *> *crashInfoMessages = [NSMutableArray new];

    NSPredicate *libSwiftCore =
        [NSPredicate predicateWithBlock:^BOOL(id object, NSDictionary *bindings) {
            NSDictionary *binaryImage = object;
            return [binaryImage[@"name"] containsString:@"libswiftCore.dylib"];
        }];
    NSArray *libSwiftCoreBinaryImages =
        [self.binaryImages filteredArrayUsingPredicate:libSwiftCore];

    for (NSDictionary *binaryImage in libSwiftCoreBinaryImages) {
        if (binaryImage[@"crash_info_message"] != nil) {
            [crashInfoMessages
                addObject:SENTRY_UNWRAP_NULLABLE(NSString, binaryImage[@"crash_info_message"])];
        }

        if (binaryImage[@"crash_info_message2"] != nil) {
            [crashInfoMessages
                addObject:SENTRY_UNWRAP_NULLABLE(NSString, binaryImage[@"crash_info_message2"])];
        }
    }

    NSString *swiftCoreCrashInfo = crashInfoMessages.firstObject;
    if (swiftCoreCrashInfo != nil) {
        exception.value = swiftCoreCrashInfo;
    }
}

- (SentryMechanism *_Nullable)extractMechanismOfType:(nonnull NSString *)type
{
    SentryMechanism *mechanism = [[SentryMechanism alloc] initWithType:type];
    if (nil != self.exceptionContext[@"mach"]) {
        mechanism.handled = @(NO);

        SentryMechanismContext *meta = [[SentryMechanismContext alloc] init];

        NSMutableDictionary *machException = [NSMutableDictionary new];
        [machException setValue:self.exceptionContext[@"mach"][@"exception_name"] forKey:@"name"];
        [machException setValue:self.exceptionContext[@"mach"][@"exception"] forKey:@"exception"];
        [machException setValue:self.exceptionContext[@"mach"][@"subcode"] forKey:@"subcode"];
        [machException setValue:self.exceptionContext[@"mach"][@"code"] forKey:@"code"];
        meta.machException = machException;

        if (nil != self.exceptionContext[@"signal"]) {
            NSMutableDictionary *signal = [NSMutableDictionary new];
            [signal setValue:self.exceptionContext[@"signal"][@"signal"] forKey:@"number"];
            [signal setValue:self.exceptionContext[@"signal"][@"code"] forKey:@"code"];
            [signal setValue:self.exceptionContext[@"signal"][@"code_name"] forKey:@"code_name"];
            [signal setValue:self.exceptionContext[@"signal"][@"name"] forKey:@"name"];
            meta.signal = signal;
        }

        mechanism.meta = meta;

        if (nil != self.exceptionContext[@"address"] &&
            [self.exceptionContext[@"address"] integerValue] > 0) {
            mechanism.data = @{
                @"relevant_address" : sentry_formatHexAddress(self.exceptionContext[@"address"])
            };
        }
    }
    return mechanism;
}

- (NSArray *)convertThreads
{
    NSMutableArray *result = [NSMutableArray new];
    for (NSInteger threadIndex = 0; threadIndex < (NSInteger)self.threads.count; threadIndex++) {
        SentryThread *thread = [self threadAtIndex:threadIndex];
        if (thread && nil != thread.stacktrace) {
            [result addObject:thread];
        }
    }
    return result;
}

@end
