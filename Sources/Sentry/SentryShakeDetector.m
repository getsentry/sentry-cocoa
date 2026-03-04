#import "SentryShakeDetector.h"
#import <objc/runtime.h>
#import <stdatomic.h>

#if TARGET_OS_IOS
#    import <QuartzCore/CABase.h>
#    import <UIKit/UIKit.h>

NSNotificationName const SentryShakeDetectedNotification = @"SentryShakeDetected";

static atomic_bool _shakeDetectionEnabled = NO;
static BOOL _swizzled = NO;
static IMP _originalMotionEndedIMP = NULL;
static CFTimeInterval _lastShakeTimestamp = 0;
static const CFTimeInterval SHAKE_COOLDOWN_SECONDS = 1.0;

static void
sentry_motionEnded(UIWindow *self, SEL _cmd, UIEventSubtype motion, UIEvent *event)
{
    if (atomic_load_explicit(&_shakeDetectionEnabled, memory_order_acquire)
        && motion == UIEventSubtypeMotionShake) {
        CFTimeInterval now = CACurrentMediaTime();
        if (now - _lastShakeTimestamp > SHAKE_COOLDOWN_SECONDS) {
            _lastShakeTimestamp = now;
            [[NSNotificationCenter defaultCenter]
                postNotificationName:SentryShakeDetectedNotification
                              object:nil];
        }
    }
    if (_originalMotionEndedIMP) {
        ((void (*)(id, SEL, UIEventSubtype, UIEvent *))_originalMotionEndedIMP)(
            self, _cmd, motion, event);
    }
}

@implementation SentryShakeDetector

+ (void)enable
{
    @synchronized(self) {
        if (!_swizzled) {
            Class windowClass = [UIWindow class];
            SEL sel = @selector(motionEnded:withEvent:);
            Method inheritedMethod = class_getInstanceMethod(windowClass, sel);
            if (!inheritedMethod) {
                return;
            }
            IMP inheritedIMP = method_getImplementation(inheritedMethod);
            const char *types = method_getTypeEncoding(inheritedMethod);
            class_addMethod(windowClass, sel, inheritedIMP, types);
            Method ownMethod = class_getInstanceMethod(windowClass, sel);
            _originalMotionEndedIMP = method_setImplementation(ownMethod, (IMP)sentry_motionEnded);
            _swizzled = YES;
        }
        atomic_store_explicit(&_shakeDetectionEnabled, YES, memory_order_release);
    }
}

+ (void)disable
{
    atomic_store_explicit(&_shakeDetectionEnabled, NO, memory_order_release);
}

@end

#else

NSNotificationName const SentryShakeDetectedNotification = @"SentryShakeDetected";

@implementation SentryShakeDetector
+ (void)enable
{
}
+ (void)disable
{
}
@end

#endif
