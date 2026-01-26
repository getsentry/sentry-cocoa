#import "SentryNSFileManagerSwizzlingHelper.h"
#import "SentrySwift.h"
#import "SentrySwizzle.h"
#import "SentryTraceOrigin.h"
#import <objc/runtime.h>

@implementation SentryNSFileManagerSwizzlingHelper

static __weak SentryFileIOTracker *_tracker = nil;
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

    // Before iOS 18.0, macOS 15.0 and tvOS 18.0 the NSFileManager used NSData.writeToFile
    // internally, which was tracked using swizzling of NSData. This behaviour changed, therefore
    // the file manager needs to swizzled for later versions.
    //
    // Ref: https://github.com/swiftlang/swift-foundation/pull/410
    if (@available(iOS 18, macOS 15, tvOS 18, *)) {
        SEL createFileAtPathContentsAttributes
            = NSSelectorFromString(@"createFileAtPath:contents:attributes:");
        SentrySwizzleInstanceMethod(NSFileManager.class, createFileAtPathContentsAttributes,
            SentrySWReturnType(BOOL),
            SentrySWArguments(
                NSString * path, NSData * data, NSDictionary<NSFileAttributeKey, id> * attributes),
            SentrySWReplacement({
                return _tracker != nil
                    ? [_tracker
                          measureNSFileManagerCreateFileAtPath:path
                                                          data:data
                                                    attributes:attributes
                                                        origin:SentryTraceOriginAutoNSData
                                                        method:^BOOL(NSString *path, NSData *data,
                                                            NSDictionary<NSFileAttributeKey, id>
                                                                *attributes) {
                                                            return SentrySWCallOriginal(
                                                                path, data, attributes);
                                                        }]
                    : SentrySWCallOriginal(path, data, attributes);
            }),
            SentrySwizzleModeOncePerClassAndSuperclasses,
            (void *)createFileAtPathContentsAttributes);
    }
}

+ (void)unswizzle
{
#if SENTRY_TEST || SENTRY_TEST_CI
    _tracker = nil;
    swizzlingIsActive = FALSE;

    // Unswizzling is only supported in test targets as it is considered unsafe for production.
    if (@available(iOS 18, macOS 15, tvOS 18, *)) {
        SEL createFileAtPathContentsAttributes
            = NSSelectorFromString(@"createFileAtPath:contents:attributes:");
        SentryUnswizzleInstanceMethod(NSFileManager.class, createFileAtPathContentsAttributes,
            (void *)createFileAtPathContentsAttributes);
    }
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
