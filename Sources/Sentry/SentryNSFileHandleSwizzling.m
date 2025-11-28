#import "SentryNSFileHandleSwizzling.h"
#import "SentryLogC.h"
#import "SentrySwift.h"
#import "SentrySwizzle.h"
#import "SentryTraceOrigin.h"
#import <objc/runtime.h>

@interface SentryNSFileHandleSwizzling ()

@property (nonatomic, strong) SentryFileIOTracker *tracker;

@end

@implementation SentryNSFileHandleSwizzling

+ (SentryNSFileHandleSwizzling *)shared
{
    static SentryNSFileHandleSwizzling *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[self alloc] init]; });
    return instance;
}

- (void)startWithOptions:(SentryOptions *)options tracker:(SentryFileIOTracker *)tracker
{
    self.tracker = tracker;

    if (!options.enableSwizzling) {
        SENTRY_LOG_DEBUG(
            @"Auto-tracking of NSFileHandle is disabled because enableSwizzling is false");
        return;
    }

    if (!options.enableFileHandleSwizzling) {
        SENTRY_LOG_DEBUG(@"Auto-tracking of NSFileHandle is disabled because "
                         @"enableFileHandleSwizzling is false");
        return;
    }

    [SentryNSFileHandleSwizzling swizzle];
}

- (void)stop
{
    [SentryNSFileHandleSwizzling unswizzle];
}

// SentrySwizzleInstanceMethod declaration shadows a local variable. The swizzling is working
// fine and we accept this warning.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wshadow"
+ (void)swizzle
{
    SEL readDataOfLengthSelector = NSSelectorFromString(@"readDataOfLength:");
    SentrySwizzleInstanceMethod(NSFileHandle.class, readDataOfLengthSelector,
        SentrySWReturnType(NSData *), SentrySWArguments(NSUInteger length), SentrySWReplacement({
            return [SentryNSFileHandleSwizzling.shared.tracker
                measureNSFileHandle:self
                   readDataOfLength:length
                             origin:SentryTraceOriginAutoNSData
                             method:^NSData *(
                                 NSUInteger length) { return SentrySWCallOriginal(length); }];
        }),
        SentrySwizzleModeOncePerClassAndSuperclasses, (void *)readDataOfLengthSelector);

    SEL readDataToEndOfFileSelector = NSSelectorFromString(@"readDataToEndOfFile");
    SentrySwizzleInstanceMethod(NSFileHandle.class, readDataToEndOfFileSelector,
        SentrySWReturnType(NSData *), SentrySWArguments(), SentrySWReplacement({
            return [SentryNSFileHandleSwizzling.shared.tracker
                measureNSFileHandle:self
                readDataToEndOfFile:SentryTraceOriginAutoNSData
                             method:^NSData *(void) { return SentrySWCallOriginal(); }];
        }),
        SentrySwizzleModeOncePerClassAndSuperclasses, (void *)readDataToEndOfFileSelector);

    SEL writeDataSelector = NSSelectorFromString(@"writeData:");
    SentrySwizzleInstanceMethod(NSFileHandle.class, writeDataSelector, SentrySWReturnType(void),
        SentrySWArguments(NSData * data), SentrySWReplacement({
            [SentryNSFileHandleSwizzling.shared.tracker
                measureNSFileHandle:self
                          writeData:data
                             origin:SentryTraceOriginAutoNSData
                             method:^void(NSData *data) { SentrySWCallOriginal(data); }];
        }),
        SentrySwizzleModeOncePerClassAndSuperclasses, (void *)writeDataSelector);

    SEL synchronizeFileSelector = NSSelectorFromString(@"synchronizeFile");
    SentrySwizzleInstanceMethod(NSFileHandle.class, synchronizeFileSelector,
        SentrySWReturnType(void), SentrySWArguments(), SentrySWReplacement({
            [SentryNSFileHandleSwizzling.shared.tracker
                measureNSFileHandle:self
                    synchronizeFile:SentryTraceOriginAutoNSData
                             method:^void(void) { SentrySWCallOriginal(); }];
        }),
        SentrySwizzleModeOncePerClassAndSuperclasses, (void *)synchronizeFileSelector);
}

+ (void)unswizzle
{
#if SENTRY_TEST || SENTRY_TEST_CI
    // Unswizzling is only supported in test targets as it is considered unsafe for production.
    SEL readDataOfLengthSelector = NSSelectorFromString(@"readDataOfLength:");
    SentryUnswizzleInstanceMethod(
        NSFileHandle.class, readDataOfLengthSelector, (void *)readDataOfLengthSelector);

    SEL readDataToEndOfFileSelector = NSSelectorFromString(@"readDataToEndOfFile");
    SentryUnswizzleInstanceMethod(
        NSFileHandle.class, readDataToEndOfFileSelector, (void *)readDataToEndOfFileSelector);

    SEL writeDataSelector = NSSelectorFromString(@"writeData:");
    SentryUnswizzleInstanceMethod(NSFileHandle.class, writeDataSelector, (void *)writeDataSelector);

    SEL synchronizeFileSelector = NSSelectorFromString(@"synchronizeFile");
    SentryUnswizzleInstanceMethod(
        NSFileHandle.class, synchronizeFileSelector, (void *)synchronizeFileSelector);
#endif // SENTRY_TEST || SENTRY_TEST_CI
}
#pragma clang diagnostic pop
@end
