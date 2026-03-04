#import "SentryShakeDetector.h"
#import <objc/runtime.h>

#if TARGET_OS_IOS
#    import <UIKit/UIKit.h>

NSNotificationName const SentryShakeDetectedNotification = @"SentryShakeDetected";

static BOOL _shakeDetectionEnabled = NO;
static BOOL _swizzled = NO;
static IMP _originalMotionEndedIMP = NULL;
static NSTimeInterval _lastShakeTimestamp = 0;
static const NSTimeInterval SHAKE_COOLDOWN_SECONDS = 1.0;

static void
sentry_motionEnded(UIWindow *self, SEL _cmd, UIEventSubtype motion, UIEvent *event)
{
    if (_shakeDetectionEnabled && motion == UIEventSubtypeMotionShake) {
        NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
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
        _shakeDetectionEnabled = YES;
    }
}

+ (void)disable
{
    @synchronized(self) {
        _shakeDetectionEnabled = NO;
    }
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
