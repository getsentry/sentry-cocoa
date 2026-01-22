#import "SentryNSDataSwizzlingHelper.h"
#import "SentrySwift.h"
#import "SentrySwizzle.h"
#import "SentryTraceOrigin.h"
#import <objc/runtime.h>

@implementation SentryNSDataSwizzlingHelper

static SentryFileIOTracker *_tracker = nil;
#if SENTRY_TEST || SENTRY_TEST_CI
static BOOL swizzlingIsActive = FALSE;
#endif

// SentrySwizzleInstanceMethod declaration shadows a local variable. The swizzling is working
// fine and we accept this warning.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wshadow"
+ (void)swizzleWithTracker:(SentryFileIOTracker *)tracker
{
    _tracker = tracker;
#if SENTRY_TEST || SENTRY_TEST_CI
    swizzlingIsActive = TRUE;
#endif

    SEL writeToFileAtomicallySelector = NSSelectorFromString(@"writeToFile:atomically:");
    SentrySwizzleInstanceMethod(NSData.class, writeToFileAtomicallySelector,
        SentrySWReturnType(BOOL), SentrySWArguments(NSString * path, BOOL useAuxiliaryFile),
        SentrySWReplacement({
            return [_tracker measureNSData:self
                               writeToFile:path
                                atomically:useAuxiliaryFile
                                    origin:SentryTraceOriginAutoNSData
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
            return [_tracker measureNSData:self
                               writeToFile:path
                                   options:writeOptionsMask
                                    origin:SentryTraceOriginAutoNSData
                                     error:error
                                    method:^BOOL(NSString *filePath, NSDataWritingOptions options,
                                        NSError **outError) {
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
            return [_tracker
                measureNSDataFromFile:path
                              options:options
                               origin:SentryTraceOriginAutoNSData
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
            return [_tracker measureNSDataFromFile:path
                                            origin:SentryTraceOriginAutoNSData
                                            method:^NSData *(NSString *filePath) {
                                                return SentrySWCallOriginal(filePath);
                                            }];
        }),
        SentrySwizzleModeOncePerClassAndSuperclasses, (void *)initWithContentsOfFileSelector);

    SEL initWithContentsOfURLOptionsErrorSelector
        = NSSelectorFromString(@"initWithContentsOfURL:options:error:");
    SentrySwizzleInstanceMethod(NSData.class, initWithContentsOfURLOptionsErrorSelector,
        SentrySWReturnType(NSData *),
        SentrySWArguments(NSURL * url, NSDataReadingOptions options, NSError * *error),
        SentrySWReplacement({
            return
                [_tracker measureNSDataFromURL:url
                                       options:options
                                        origin:SentryTraceOriginAutoNSData
                                         error:error
                                        method:^NSData *(NSURL *fileUrl,
                                            NSDataReadingOptions options, NSError **outError) {
                                            return SentrySWCallOriginal(fileUrl, options, outError);
                                        }];
        }),
        SentrySwizzleModeOncePerClassAndSuperclasses,
        (void *)initWithContentsOfURLOptionsErrorSelector);
}

+ (void)unswizzle
{
#if SENTRY_TEST || SENTRY_TEST_CI
    _tracker = nil;
    swizzlingIsActive = FALSE;

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
#endif // SENTRY_TEST || SENTRY_TEST_CI
}
#pragma clang diagnostic pop

#if SENTRY_TEST || SENTRY_TEST_CI
+ (BOOL)swizzlingActive
{
    return swizzlingIsActive;
}
#endif
@end
