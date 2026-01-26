#import "SentryCoreDataSwizzlingHelper.h"
#import "SentryCoreDataTracker.h"
#import "SentrySwift.h"
#import "SentrySwizzle.h"
#import <CoreData/CoreData.h>
#import <objc/runtime.h>

@implementation SentryCoreDataSwizzlingHelper

static __weak SentryCoreDataTracker *_tracker = nil;
#if SENTRY_TEST || SENTRY_TEST_CI
static BOOL swizzlingIsActive = FALSE;
#endif

// SentrySwizzleInstanceMethod declaration shadows a local variable. The swizzling is working
// fine and we accept this warning.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wshadow"
+ (void)swizzleWithTracker:(SentryCoreDataTracker *)tracker
{
    _tracker = tracker;
#if SENTRY_TEST || SENTRY_TEST_CI
    swizzlingIsActive = TRUE;
#endif

    SEL fetchSelector = NSSelectorFromString(@"executeFetchRequest:error:");
    SentrySwizzleInstanceMethod(NSManagedObjectContext.class, fetchSelector,
        SentrySWReturnType(NSArray *),
        SentrySWArguments(NSFetchRequest * originalRequest, NSError * *error), SentrySWReplacement({
            SentryCoreDataTracker *tracker = _tracker;
            return tracker != nil
                ? [tracker
                      managedObjectContext:self
                       executeFetchRequest:originalRequest
                                     error:error
                               originalImp:^NSArray *(NSFetchRequest *request, NSError **outError) {
                                   return SentrySWCallOriginal(request, outError);
                               }]
                : SentrySWCallOriginal(originalRequest, error);
        }),
        SentrySwizzleModeOncePerClassAndSuperclasses, (void *)fetchSelector);

    SEL saveSelector = NSSelectorFromString(@"save:");
    SentrySwizzleInstanceMethod(NSManagedObjectContext.class, saveSelector,
        SentrySWReturnType(BOOL), SentrySWArguments(NSError * *error), SentrySWReplacement({
            SentryCoreDataTracker *tracker = _tracker;
            return tracker != nil ? [tracker managedObjectContext:self
                                                             save:error
                                                      originalImp:^BOOL(NSError **outError) {
                                                          return SentrySWCallOriginal(outError);
                                                      }]
                                  : SentrySWCallOriginal(error);
        }),
        SentrySwizzleModeOncePerClassAndSuperclasses, (void *)saveSelector);
}

+ (void)unswizzle
{
#if SENTRY_TEST || SENTRY_TEST_CI
    _tracker = nil;
    swizzlingIsActive = FALSE;

    // Unswizzling is only supported in test targets as it is considered unsafe for production.
    SEL fetchSelector = NSSelectorFromString(@"executeFetchRequest:error:");
    SentryUnswizzleInstanceMethod(
        NSManagedObjectContext.class, fetchSelector, (void *)fetchSelector);

    SEL saveSelector = NSSelectorFromString(@"save:");
    SentryUnswizzleInstanceMethod(NSManagedObjectContext.class, saveSelector, (void *)saveSelector);
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
