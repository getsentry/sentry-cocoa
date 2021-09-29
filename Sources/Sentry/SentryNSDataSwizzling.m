#import "SentryNSDataSwizzling.h"
#import "SentryNSDataTracker.h"
#import "SentrySwizzle.h"
#import <SentryLog.h>
#import <objc/runtime.h>

@implementation SentryNSDataSwizzling

+ (void)start
{
    [SentryNSDataTracker.sharedInstance enable];
    [self swizzleNSData];
}

+ (void)stop
{
    [SentryNSDataTracker.sharedInstance disable];
}
// SentrySwizzleInstanceMethod declaration shadows a local variable. The swizzling is working
// fine and we accept this warning.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wshadow"
+ (void)swizzleNSData
{
    SEL writeToFileAtomicallySelector = NSSelectorFromString(@"writeToFile:atomically:");
    SentrySwizzleInstanceMethod(NSData.class, writeToFileAtomicallySelector, SentrySWReturnType(BOOL),
        SentrySWArguments(NSString* path, BOOL useAuxiliaryFile), SentrySWReplacement({
            return SentrySWCallOriginal(path, useAuxiliaryFile);
        }),
        SentrySwizzleModeOncePerClassAndSuperclasses, (void *)writeToFileAtomicallySelector);
    
    SEL writeToFileOptionsErrorSelector = NSSelectorFromString(@"writeToFile:options:error:");
    SentrySwizzleInstanceMethod(NSData.class, writeToFileOptionsErrorSelector, SentrySWReturnType(BOOL),
        SentrySWArguments(NSString* path, NSDataWritingOptions writeOptionsMask, NSError** error), SentrySWReplacement({
            return SentrySWCallOriginal(path, writeOptionsMask, error);
        }),
        SentrySwizzleModeOncePerClassAndSuperclasses, (void *)writeToFileOptionsErrorSelector);
}
#pragma clang diagnostic pop
@end

/*
 - writeToFile:atomically:
 Writes the data object's bytes to the file specified by a given path.
 - writeToFile:options:error:
 Writes the data object's bytes to the file specified by a given path.
 - writeToURL:atomically:
 Writes the data object's bytes to the location specified by a given URL.
 - writeToURL:options:error:
 Writes the data object's bytes to the location specified by a given URL.
 */
