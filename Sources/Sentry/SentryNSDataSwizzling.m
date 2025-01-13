#import "SentryNSDataSwizzling.h"
#import "SentryLog.h"
#import "SentrySwizzle.h"
#import <objc/runtime.h>

@interface SentryNSDataSwizzling ()

@property (nonatomic, strong) SentryFileIOTracker *tracker;

@end

@implementation SentryNSDataSwizzling

+ (SentryNSDataSwizzling *)shared
{
    static SentryNSDataSwizzling *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[self alloc] init]; });
    return instance;
}

- (void)startWithOptions:(SentryOptions *)options tracker:(SentryFileIOTracker *)tracker
{
    self.tracker = tracker;

    [SentryNSDataSwizzling swizzle];
}

- (void)stop
{
    [SentryNSDataSwizzling unswizzle];
}

// SentrySwizzleInstanceMethod declaration shadows a local variable. The swizzling is working
// fine and we accept this warning.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wshadow"
+ (void)swizzle
{
    SEL writeToFileAtomicallySelector = NSSelectorFromString(@"writeToFile:atomically:");
    SentrySwizzleInstanceMethod(NSData.class, writeToFileAtomicallySelector,
        SentrySWReturnType(BOOL), SentrySWArguments(NSString * path, BOOL useAuxiliaryFile),
        SentrySWReplacement({
            return [SentryNSDataSwizzling.shared.tracker
                measureNSData:self
                  writeToFile:path
                   atomically:useAuxiliaryFile
                       origin:SentryTraceOrigin.autoNSData
                       method:^BOOL(NSString *_Nonnull filePath, BOOL isAtomically) {
                           return SentrySWCallOriginal(filePath, isAtomically);
                       }];
        }),
        SentrySwizzleModeOncePerClassAndSuperclasses, (void *)writeToFileAtomicallySelector);

    SEL writeToFileOptionsErrorSelector = NSSelectorFromString(@"writeToFile:options:error:");
    SentrySwizzleInstanceMethod(NSData.class, writeToFileOptionsErrorSelector,
        SentrySWReturnType(BOOL),
        SentrySWArguments(NSString * path, NSDataWritingOptions writeOptionsMask, NSError * *error),
        SentrySWReplacement({
            return [SentryNSDataSwizzling.shared.tracker
                measureNSData:self
                  writeToFile:path
                      options:writeOptionsMask
                       origin:SentryTraceOrigin.autoNSData
                        error:error
                       method:^BOOL(
                           NSString *filePath, NSDataWritingOptions options, NSError **outError) {
                           return SentrySWCallOriginal(filePath, options, outError);
                       }];
        }),
        SentrySwizzleModeOncePerClassAndSuperclasses, (void *)writeToFileOptionsErrorSelector);

    SEL initWithContentOfFileOptionsErrorSelector
        = NSSelectorFromString(@"initWithContentsOfFile:options:error:");
    SentrySwizzleInstanceMethod(NSData.class, initWithContentOfFileOptionsErrorSelector,
        SentrySWReturnType(NSData *),
        SentrySWArguments(NSString * path, NSDataReadingOptions options, NSError * *error),
        SentrySWReplacement({
            return [SentryNSDataSwizzling.shared.tracker
                measureNSDataFromFile:path
                              options:options
                               origin:SentryTraceOrigin.autoNSData
                                error:error
                               method:^NSData *(NSString *filePath, NSDataReadingOptions options,
                                   NSError **outError) {
                                   return SentrySWCallOriginal(filePath, options, outError);
                               }];
        }),
        SentrySwizzleModeOncePerClassAndSuperclasses,
        (void *)initWithContentOfFileOptionsErrorSelector);

    SEL initWithContentsOfFileSelector = NSSelectorFromString(@"initWithContentsOfFile:");
    SentrySwizzleInstanceMethod(NSData.class, initWithContentsOfFileSelector,
        SentrySWReturnType(NSData *), SentrySWArguments(NSString * path), SentrySWReplacement({
            return [SentryNSDataSwizzling.shared.tracker
                measureNSDataFromFile:path
                               origin:SentryTraceOrigin.autoNSData
                               method:^NSData *(
                                   NSString *filePath) { return SentrySWCallOriginal(filePath); }];
        }),
        SentrySwizzleModeOncePerClassAndSuperclasses, (void *)initWithContentsOfFileSelector);

    SEL initWithContentsOfURLOptionsErrorSelector
        = NSSelectorFromString(@"initWithContentsOfURL:options:error:");
    SentrySwizzleInstanceMethod(NSData.class, initWithContentsOfURLOptionsErrorSelector,
        SentrySWReturnType(NSData *),
        SentrySWArguments(NSURL * url, NSDataReadingOptions options, NSError * *error),
        SentrySWReplacement({
            return [SentryNSDataSwizzling.shared.tracker
                measureNSDataFromURL:url
                             options:options
                              origin:SentryTraceOrigin.autoNSData
                               error:error
                              method:^NSData *(NSURL *fileUrl, NSDataReadingOptions options,
                                  NSError **outError) {
                                  return SentrySWCallOriginal(fileUrl, options, outError);
                              }];
        }),
        SentrySwizzleModeOncePerClassAndSuperclasses,
        (void *)initWithContentsOfURLOptionsErrorSelector);
}

+ (void)unswizzle
{
#if TEST || TESTCI
    // Unswizzling is only supported in test targets as it is considered unsafe for production.
    SEL writeToFileAtomicallySelector = NSSelectorFromString(@"writeToFile:atomically:");
    SentryUnswizzleInstanceMethod(
        NSData.class, writeToFileAtomicallySelector, (void *)writeToFileAtomicallySelector);

    SEL writeToFileOptionsErrorSelector = NSSelectorFromString(@"writeToFile:options:error:");
    SentryUnswizzleInstanceMethod(
        NSData.class, writeToFileOptionsErrorSelector, (void *)writeToFileOptionsErrorSelector);

    SEL initWithContentOfFileOptionsErrorSelector
        = NSSelectorFromString(@"initWithContentsOfFile:options:error:");
    SentryUnswizzleInstanceMethod(NSData.class, initWithContentOfFileOptionsErrorSelector,
        (void *)initWithContentOfFileOptionsErrorSelector);

    SEL initWithContentsOfFileSelector = NSSelectorFromString(@"initWithContentsOfFile:");
    SentryUnswizzleInstanceMethod(
        NSData.class, initWithContentsOfFileSelector, (void *)initWithContentsOfFileSelector);

    SEL initWithContentsOfURLOptionsErrorSelector
        = NSSelectorFromString(@"initWithContentsOfURL:options:error:");
    SentryUnswizzleInstanceMethod(NSData.class, initWithContentsOfURLOptionsErrorSelector,
        (void *)initWithContentsOfURLOptionsErrorSelector);
#endif // TEST || TESTCI
}
#pragma clang diagnostic pop
@end
