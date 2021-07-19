#import "SentryUIViewControllerSwizziling.h"
#import "SentryLog.h"
#import "SentryPerformanceTracker.h"
#import "SentrySwizzle.h"
#import "SentryUIViewControllerPerformanceTracker.h"
#import <objc/runtime.h>

#if SENTRY_HAS_UIKIT
#    import <UIKit/UIKit.h>

@implementation SentryUIViewControllerSwizziling

+ (void)start
{
    [SentryUIViewControllerSwizziling swizzleViewControllerInits];
}

NSArray<Class>*ClassGetSubclasses(Class parentClass)
{
  int numClasses = objc_getClassList(NULL, 0);
  Class *classes = NULL;

  classes = (__unsafe_unretained Class *)malloc(sizeof(Class) * numClasses);
  numClasses = objc_getClassList(classes, numClasses);

  NSMutableArray *result = [NSMutableArray array];
  for (NSInteger i = 0; i < numClasses; i++)
  {
    Class superClass = classes[i];
    do
    {
      superClass = class_getSuperclass(superClass);
    } while(superClass && superClass != parentClass);

    if (superClass == nil)
    {
      continue;
    }

    [result addObject:classes[i]];
  }

  free(classes);

  return result;
}

// SentrySwizzleInstanceMethod declaration shadows a local variable. The swizzling is working
// fine and we accept this warning.
#    pragma clang diagnostic push
#    pragma clang diagnostic ignored "-Wshadow"

/**
 * Swizzle the some init methods of the view controller,
 * so we can swizzle user view controller subclass on demand.
 */
+ (void)swizzleViewControllerInits
{
    NSArray<Class>* viewControllers =  ClassGetSubclasses([UIViewController class]);
    
    for (Class viewController in viewControllers) {
        [SentryUIViewControllerSwizziling swizzleViewControllerSubClass:viewController];
    }
    

    
    
//    static const void *swizzleViewControllerInitWithCoder = &swizzleViewControllerInitWithCoder;
//    SEL coderSelector = NSSelectorFromString(@"initWithCoder:");
//    SentrySwizzleInstanceMethod(UIViewController.class, coderSelector, SentrySWReturnType(id),
//        SentrySWArguments(NSCoder * coder), SentrySWReplacement({
//            [SentryUIViewControllerSwizziling swizzleViewControllerSubClass:[self class]];
//            return SentrySWCallOriginal(coder);
//        }),
//        SentrySwizzleModeOncePerClassAndSuperclasses, swizzleViewControllerInitWithCoder);
//
//    static const void *swizzleViewControllerInitWithNib = &swizzleViewControllerInitWithNib;
//    SEL nibSelector = NSSelectorFromString(@"initWithNibName:bundle:");
//    SentrySwizzleInstanceMethod(UIViewController.class, nibSelector, SentrySWReturnType(id),
//        SentrySWArguments(NSString * nibName, NSBundle * bundle), SentrySWReplacement({
//            [SentryUIViewControllerSwizziling swizzleViewControllerSubClass:[self class]];
//            return SentrySWCallOriginal(nibName, bundle);
//        }),
//        SentrySwizzleModeOncePerClassAndSuperclasses, swizzleViewControllerInitWithNib);
}

+ (void)swizzleViewControllerSubClass:(Class)class
{
    // Swizzling only classes from the user app module to avoid track every UIKit view controller
    // interaction.
    static const char *appImage = nil;
    if (appImage == nil) {
        if ([UIApplication respondsToSelector:@selector(sharedApplication)]) {
            UIApplication *app = [UIApplication performSelector:@selector(sharedApplication)];
            appImage = class_getImageName(app.delegate.class);
        }
    }
    if (appImage == nil || strcmp(appImage, class_getImageName(class)) != 0)
        return;

    // This are the five main functions related to UI creation in a view controller.
    // We are swizzling it to track anything that happens inside one of this functions.
    [SentryUIViewControllerSwizziling swizzleViewLayoutSubViews:class];
    [SentryUIViewControllerSwizziling swizzleLoadView:class];
    [SentryUIViewControllerSwizziling swizzleViewDidLoad:class];
    [SentryUIViewControllerSwizziling swizzleViewWillAppear:class];
    [SentryUIViewControllerSwizziling swizzleViewDidAppear:class];
}

+ (void)swizzleLoadView:(Class)class
{
    SEL selector = NSSelectorFromString(@"loadView");
    SentrySwizzleInstanceMethod(class, selector, SentrySWReturnType(void), SentrySWArguments(),
        SentrySWReplacement({
            [SentryUIViewControllerPerformanceTracker.shared
                viewControllerLoadView:self
                      callbackToOrigin:^{ SentrySWCallOriginal(); }];
        }),
        SentrySwizzleModeOncePerClassAndSuperclasses, (void *)selector);
}

+ (void)swizzleViewDidLoad:(Class)class
{
    SEL selector = NSSelectorFromString(@"viewDidLoad");
    SentrySwizzleInstanceMethod(class, selector, SentrySWReturnType(void), SentrySWArguments(),
        SentrySWReplacement({
            [SentryUIViewControllerPerformanceTracker.shared
                viewControllerViewDidLoad:self
                         callbackToOrigin:^{ SentrySWCallOriginal(); }];
        }),
        SentrySwizzleModeOncePerClassAndSuperclasses, (void *)selector);
}

+ (void)swizzleViewWillAppear:(Class)class
{
    SEL selector = NSSelectorFromString(@"viewWillAppear:");
    SentrySwizzleInstanceMethod(class, selector, SentrySWReturnType(void),
        SentrySWArguments(BOOL animated), SentrySWReplacement({
            [SentryUIViewControllerPerformanceTracker.shared
                viewControllerViewWillAppear:self
                            callbackToOrigin:^{ SentrySWCallOriginal(animated); }];
        }),
        SentrySwizzleModeOncePerClassAndSuperclasses, (void *)selector);
}

+ (void)swizzleViewDidAppear:(Class)class
{
    SEL selector = NSSelectorFromString(@"viewDidAppear:");
    SentrySwizzleInstanceMethod(class, selector, SentrySWReturnType(void),
        SentrySWArguments(BOOL animated), SentrySWReplacement({
            [SentryUIViewControllerPerformanceTracker.shared
                viewControllerViewDidAppear:self
                           callbackToOrigin:^{ SentrySWCallOriginal(animated); }];
        }),
        SentrySwizzleModeOncePerClassAndSuperclasses, (void *)selector);
}

+ (void)swizzleViewLayoutSubViews:(Class)class
{
    SEL willSelector = NSSelectorFromString(@"viewWillLayoutSubviews");
    SentrySwizzleInstanceMethod(class, willSelector, SentrySWReturnType(void), SentrySWArguments(),
        SentrySWReplacement({
            [SentryUIViewControllerPerformanceTracker.shared
                viewControllerViewWillLayoutSubViews:self
                                    callbackToOrigin:^{ SentrySWCallOriginal(); }];
        }),
        SentrySwizzleModeOncePerClassAndSuperclasses, (void *)willSelector);

    SEL didSelector = NSSelectorFromString(@"viewDidLayoutSubviews");
    SentrySwizzleInstanceMethod(class, didSelector, SentrySWReturnType(void), SentrySWArguments(),
        SentrySWReplacement({
            [SentryUIViewControllerPerformanceTracker.shared
                viewControllerViewDidLayoutSubViews:self
                                   callbackToOrigin:^{ SentrySWCallOriginal(); }];
        }),
        SentrySwizzleModeOncePerClassAndSuperclasses, (void *)didSelector);
}

@end

#    pragma clang diagnostic pop
#endif
