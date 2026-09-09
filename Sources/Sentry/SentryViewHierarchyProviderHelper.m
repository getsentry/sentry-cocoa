#import "SentryViewHierarchyProviderHelper.h"

#if SENTRY_HAS_UIKIT

#    import "SentryFileIO.h"
#    import "SentryJSONStreamWriter.h"
#    import "SentryLogC.h"
#    import "SentrySwift.h"
#    import <UIKit/UIKit.h>
#    include <errno.h>
#    include <fcntl.h>
#    include <unistd.h>

// Each view nesting level opens two containers: the view object and its children array.
// Keep the traversal below the stream writer's fixed container budget and leave room for
// the truncation marker.
#    define SENTRY_VIEW_HIERARCHY_MAX_DEPTH 90

static bool
writeJSONDataToFile(const char *const data, const size_t length, void *const userData)
{
    const int fd = *((int *)userData);
    return sentryFileIO_writeBytesToFD(fd, data, length);
}

static bool
writeJSONDataToMemory(const char *const data, const size_t length, void *const userData)
{
    NSMutableData *memory = ((__bridge NSMutableData *)userData);
    [memory appendBytes:data length:length];
    return true;
}

@interface SentryViewHierarchyProviderHelper ()

+ (BOOL)streamViewHierarchy:(NSArray<UIWindow *> *)windows
    reportAccessibilityIdentifier:(BOOL)reportAccessibilityIdentifier
                      addFunction:(SentryJSONStreamWriteFunc)addJSONDataFunc
                         userData:(nullable void *)userData;

+ (BOOL)viewHierarchyFromView:(UIView *)view
                       intoWriter:(SentryJSONStreamWriter *)writer
    reportAccessibilityIdentifier:(BOOL)reportAccessibilityIdentifier
                            depth:(NSUInteger)depth;

@end

@implementation SentryViewHierarchyProviderHelper

+ (BOOL)saveViewHierarchy:(NSString *)filePath
                          windows:(NSArray<UIWindow *> *)windows
    reportAccessibilityIdentifier:(BOOL)reportAccessibilityIdentifier
{
    const char *path = filePath.UTF8String;
    int fd = open(path, O_RDWR | O_CREAT | O_TRUNC, 0644);
    if (fd < 0) {
        SENTRY_LOG_DEBUG(@"Could not open file %s for writing: %s", path, SENTRY_STRERROR_R(errno));
        return NO;
    }

    const BOOL result = [self streamViewHierarchy:windows
                    reportAccessibilityIdentifier:reportAccessibilityIdentifier
                                      addFunction:writeJSONDataToFile
                                         userData:&fd];

    close(fd);
    return result;
}

+ (NSData *)appViewHierarchyFrom:(NSArray<UIWindow *> *)windows
    reportAccessibilityIdentifier:(BOOL)reportAccessibilityIdentifier
{
    NSMutableData *result = [[NSMutableData alloc] init];

    if (![self streamViewHierarchy:windows
            reportAccessibilityIdentifier:reportAccessibilityIdentifier
                              addFunction:writeJSONDataToMemory
                                 userData:(__bridge void *)result]) {
        return nil;
    }

    return result;
}

+ (BOOL)streamViewHierarchy:(NSArray<UIWindow *> *)windows
    reportAccessibilityIdentifier:(BOOL)reportAccessibilityIdentifier
                      addFunction:(SentryJSONStreamWriteFunc)addJSONDataFunc
                         userData:(void *const)userData
{
    if (addJSONDataFunc == NULL) {
        return NO;
    }

    SentryJSONStreamWriter writer;
    sentryJSONStreamWriter_init(&writer, addJSONDataFunc, userData);

    SENTRY_LOG_DEBUG(@"Processing view hierarchy.");

    if (!sentryJSONStreamWriter_beginObject(&writer, NULL)
        || !sentryJSONStreamWriter_addString(&writer, "rendering_system", "UIKIT")
        || !sentryJSONStreamWriter_beginArray(&writer, "windows")) {
        SENTRY_LOG_DEBUG(@"Could not create view hierarchy json: output rejected data");
        return NO;
    }

    for (UIView *window in windows) {
        if (![self viewHierarchyFromView:window
                                   intoWriter:&writer
                reportAccessibilityIdentifier:reportAccessibilityIdentifier
                                        depth:0]) {
            SENTRY_LOG_DEBUG(@"Could not create view hierarchy json: serialization failed");
            return NO;
        }
    }

    if (!sentryJSONStreamWriter_endContainer(&writer)
        || !sentryJSONStreamWriter_endContainer(&writer)
        || !sentryJSONStreamWriter_finish(&writer)) {
        SENTRY_LOG_DEBUG(@"Could not create view hierarchy json: output rejected data");
        return NO;
    }
    return YES;
}

+ (BOOL)viewHierarchyFromView:(UIView *)view
                       intoWriter:(SentryJSONStreamWriter *)writer
    reportAccessibilityIdentifier:(BOOL)reportAccessibilityIdentifier
                            depth:(NSUInteger)depth
{
    SENTRY_LOG_DEBUG(@"Processing view hierarchy of view: %@", view);

    if (!sentryJSONStreamWriter_beginObject(writer, NULL)
        || !sentryJSONStreamWriter_addString(
            writer, "type", [SwiftDescriptor getObjectClassName:view].UTF8String)) {
        return NO;
    }

    if (reportAccessibilityIdentifier && view.accessibilityIdentifier.length != 0
        && !sentryJSONStreamWriter_addString(
            writer, "identifier", view.accessibilityIdentifier.UTF8String)) {
        return NO;
    }

    if (!sentryJSONStreamWriter_addDouble(writer, "width", view.frame.size.width)
        || !sentryJSONStreamWriter_addDouble(writer, "height", view.frame.size.height)
        || !sentryJSONStreamWriter_addDouble(writer, "x", view.frame.origin.x)
        || !sentryJSONStreamWriter_addDouble(writer, "y", view.frame.origin.y)
        || !sentryJSONStreamWriter_addDouble(writer, "alpha", view.alpha)
        || !sentryJSONStreamWriter_addBool(writer, "visible", !view.hidden)) {
        return NO;
    }

    if ([view.nextResponder isKindOfClass:[UIViewController class]]) {
        UIViewController *viewController = (UIViewController *)view.nextResponder;
        if (viewController.view == view
            && !sentryJSONStreamWriter_addString(writer, "view_controller",
                [SwiftDescriptor getViewControllerClassName:viewController].UTF8String)) {
            return NO;
        }
    }

    if (!sentryJSONStreamWriter_beginArray(writer, "children")) {
        return NO;
    }
    if (depth >= SENTRY_VIEW_HIERARCHY_MAX_DEPTH && view.subviews.count > 0) {
        if (!sentryJSONStreamWriter_beginObject(writer, NULL)
            || !sentryJSONStreamWriter_addString(writer, "type", "SentryTruncatedViewHierarchy")
            || !sentryJSONStreamWriter_endContainer(writer)) {
            return NO;
        }
    } else {
        for (UIView *child in view.subviews) {
            if (![self viewHierarchyFromView:child
                                       intoWriter:writer
                    reportAccessibilityIdentifier:reportAccessibilityIdentifier
                                            depth:depth + 1]) {
                return NO;
            }
        }
    }
    return sentryJSONStreamWriter_endContainer(writer)
        && sentryJSONStreamWriter_endContainer(writer);
}

@end

#endif // SENTRY_HAS_UIKIT
