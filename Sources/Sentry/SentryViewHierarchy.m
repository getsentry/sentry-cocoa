#import "SentryViewHierarchy.h"
#import "SentryDependencyContainer.h"
#import "SentryUIApplication.h"

#if SENTRY_HAS_UIKIT
#    import <UIKit/UIKit.h>

@interface
UIView (Debugging)
- (id)recursiveDescription;
@end

@implementation SentryViewHierarchy

- (NSArray<NSString *> *)fetchViewHierarchy
{
    return [self fetchViewHierarchyPreventMoveToMainThread:NO];
}

- (NSArray<NSString *> *)fetchViewHierarchyPreventMoveToMainThread:(BOOL)preventMoveToMainThread
{
    NSArray<UIWindow *> *windows = [SentryDependencyContainer.sharedInstance.application windows];

    NSMutableArray *result = [NSMutableArray arrayWithCapacity:[windows count]];

    [windows enumerateObjectsUsingBlock:^(UIWindow *window, NSUInteger idx, BOOL *stop) {
        // In the case of a crash we can't dispatch work to be executed anymore,
        // so we'll run this on the wrong thread.
        if ([NSThread isMainThread] || preventMoveToMainThread) {
            [result addObject:[window recursiveDescription]];
        } else {
            dispatch_sync(
                dispatch_get_main_queue(), ^{ [result addObject:[window recursiveDescription]]; });
        }
    }];

    return result;
}

- (void)saveViewHierarchy:(NSString *)path
{
    [[self fetchViewHierarchyPreventMoveToMainThread:YES]
        enumerateObjectsUsingBlock:^(NSString *description, NSUInteger idx, BOOL *stop) {
            NSString *fileName =
                [NSString stringWithFormat:@"view-hierarchy-%lu.txt", (unsigned long)idx];
            NSString *filePath = [path stringByAppendingPathComponent:fileName];
            NSData *data = [description dataUsingEncoding:NSUTF8StringEncoding];
            [data writeToFile:filePath atomically:YES];
        }];
}

@end

#endif
