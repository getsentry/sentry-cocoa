#import "SentryNSFileManagerSwizzling.h"
#import "SentryCrashDefaultMachineContextWrapper.h"
#import "SentryCrashMachineContextWrapper.h"
#import "SentryCrashStackEntryMapper.h"
#import "SentryDependencyContainer.h"
#import "SentryInAppLogic.h"
#import "SentryNSDataTracker.h"
#import "SentryNSProcessInfoWrapper.h"
#import "SentryOptions+Private.h"
#import "SentryStacktraceBuilder.h"
#import "SentrySwizzle.h"
#import "SentryThreadInspector.h"
#import <SentryLog.h>
#import <objc/runtime.h>

@interface SentryNSFileManagerSwizzling ()

@property (nonatomic, strong) SentryNSDataTracker *dataTracker;

@end

@implementation SentryNSFileManagerSwizzling

+ (SentryNSFileManagerSwizzling *)shared
{
    static SentryNSFileManagerSwizzling *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[self alloc] init]; });
    return instance;
}

- (void)startWithOptions:(SentryOptions *)options
{
    self.dataTracker = [[SentryNSDataTracker alloc]
        initWithThreadInspector:[[SentryThreadInspector alloc] initWithOptions:options]
             processInfoWrapper:[SentryDependencyContainer.sharedInstance processInfoWrapper]];
    [self.dataTracker enable];
    [SentryNSFileManagerSwizzling swizzleNSFileManager];
}

- (void)stop
{
    [self.dataTracker disable];
}

// SentrySwizzleInstanceMethod declaration shadows a local variable. The swizzling is working
// fine and we accept this warning.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wshadow"
+ (void)swizzleNSFileManager
{
    // Before iOS 18.0 and macOS 15.0 the NSFileManager used NSData.writeToFile internally,
    // which was tracked using swizzling of NSData. This behaviour changed, therefore the
    // file manager needs to swizzled for later versions.
    if (@available(iOS 18, macOS 15, *)) {
        SEL createFileAtPathContentsAttributes
            = NSSelectorFromString(@"createFileAtPath:contents:attributes:");
        SentrySwizzleInstanceMethod(NSFileManager.class, createFileAtPathContentsAttributes,
            SentrySWReturnType(BOOL),
            SentrySWArguments(
                NSString * path, NSData * data, NSDictionary<NSFileAttributeKey, id> * attributes),
            SentrySWReplacement({
                return [SentryNSFileManagerSwizzling.shared.dataTracker
                    measureNSFileManagerCreateFileAtPath:path
                                                    data:data
                                              attributes:attributes
                                                  method:^BOOL(NSString *path, NSData *data,
                                                      NSDictionary<NSFileAttributeKey, id>
                                                          *attributes) {
                                                      return SentrySWCallOriginal(
                                                          path, data, attributes);
                                                  }];
            }),
            SentrySwizzleModeOncePerClassAndSuperclasses,
            (void *)createFileAtPathContentsAttributes);
    }
}
#pragma clang diagnostic pop
@end
