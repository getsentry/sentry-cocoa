//
//  SentrySwizzle.m
//  Sentry
//
//  Created by Daniel Griesser on 31/05/2017.
//  Copyright © 2017 Sentry. All rights reserved.
//  Original implementation by Yan Rabovik on 05.09.13 https://github.com/rabovik/RSSwizzle


#if __has_include(<Sentry/Sentry.h>)

#import <Sentry/SentrySwizzle.h>

#else
#import "SentrySwizzle.h"
#endif

#import <objc/runtime.h>
#include <dlfcn.h>

// Use os_unfair_lock over OSSpinLock when building with the following SDKs: iOS 10, macOS 10.12 and any tvOS and watchOS
#define DEPLOYMENT_TARGET_HIGHER_THAN_10 TARGET_OS_WATCH || TARGET_OS_TV || (TARGET_OS_IOS &&__IPHONE_OS_VERSION_MIN_REQUIRED >= 100000) || (!TARGET_OS_IPHONE && __MAC_OS_X_VERSION_MIN_ALLOWED >= 101200)

#define BASE_SDK_HIGHER_THAN_10 (TARGET_OS_WATCH || TARGET_OS_TV || (TARGET_OS_IOS &&__IPHONE_OS_VERSION_MAX_ALLOWED >= 100000) || (!TARGET_OS_IPHONE && __MAC_OS_X_VERSION_MAX_ALLOWED >= 101200))


#if BASE_SDK_HIGHER_THAN_10
#import <os/lock.h>
#else
// Below iOS 10, OS_UNFAIR_LOCK_INIT will not exist. Note that this type works with OSSpinLock
#define OS_UNFAIR_LOCK_INIT ((os_unfair_lock){0})

typedef struct _os_unfair_lock_s {
    uint32_t _os_unfair_lock_opaque;
} os_unfair_lock, *os_unfair_lock_t;
#endif


#if !DEPLOYMENT_TARGET_HIGHER_THAN_10

#import <libkern/OSAtomic.h>

#endif


// NSDimension was introduced at the same time that os_unfair_lock_lock was made public, ie. iOS 10
#define DEVICE_HIGHER_THAN_10 objc_getClass("NSDimension")


#pragma mark Locking

// This function will lock a lock using os_unfair_lock_lock (on ios10/macos10.12) or OSSpinLockLock (9 and lower).
static void chooseLock(os_unfair_lock *lock) {
#if DEPLOYMENT_TARGET_HIGHER_THAN_10
    // iOS 10+, os_unfair_lock_lock is available
    os_unfair_lock_lock(lock);
#else
    if (DEVICE_HIGHER_THAN_10) {
        // Attempt to use os_unfair_lock_lock().
        void (*os_unfair_lock_lock)(void *lock) = dlsym(dlopen(NULL, RTLD_NOW | RTLD_GLOBAL), "os_unfair_lock_lock");
        if (os_unfair_lock_lock != NULL) {
            os_unfair_lock_lock(lock);
            return;
        }
    }

    // Unfair locks are not available on iOS 9 and lower, using deprecated OSSpinLock.
    OSSpinLockLock((void *) lock);
#endif
}

// This function will unlock a lock using os_unfair_lock_unlock (on ios10/macos10.12) or OSSpinLockUnlock (9 and lower).
static void chooseUnlock(os_unfair_lock *lock) {
#if DEPLOYMENT_TARGET_HIGHER_THAN_10
    // iOS 10+, os_unfair_lock_unlock is available
    os_unfair_lock_unlock(lock);
#else
    if (DEVICE_HIGHER_THAN_10) {
        // Attempt to use os_unfair_lock_unlock().
        void (*os_unfair_lock_unlock)(void *lock) = dlsym(dlopen(NULL, RTLD_NOW | RTLD_GLOBAL), "os_unfair_lock_unlock");
        if (os_unfair_lock_unlock != NULL) {
            os_unfair_lock_unlock(lock);
            return;
        }
    }

    // Unfair locks are not available on iOS 9 and lower, using deprecated OSSpinUnlock.
    OSSpinLockUnlock((void *) lock);
#endif
}

#pragma mark - Swizzling

#pragma mark └ SentrySwizzleInfo

typedef IMP (^SentrySwizzleImpProvider)(void);

@interface SentrySwizzleInfo ()
@property(nonatomic, copy) SentrySwizzleImpProvider impProviderBlock;
@property(nonatomic, readwrite) SEL selector;
@end

@implementation SentrySwizzleInfo

- (SentrySwizzleOriginalIMP)getOriginalImplementation {
    NSAssert(_impProviderBlock, nil);
    // Casting IMP to SentrySwizzleOriginalIMP to force user casting.
    return (SentrySwizzleOriginalIMP) _impProviderBlock();
}

@end


#pragma mark └ SentrySwizzle

@implementation SentrySwizzle

static void swizzle(Class classToSwizzle,
        SEL selector,
        SentrySwizzleImpFactoryBlock factoryBlock) {
    Method method = class_getInstanceMethod(classToSwizzle, selector);

    NSCAssert(NULL != method,
            @"Selector %@ not found in %@ methods of class %@.",
            NSStringFromSelector(selector),
            class_isMetaClass(classToSwizzle) ? @"class" : @"instance",
            classToSwizzle);

    __block os_unfair_lock lock = OS_UNFAIR_LOCK_INIT;

    // To keep things thread-safe, we fill in the originalIMP later,
    // with the result of the class_replaceMethod call below.
    __block IMP originalIMP = NULL;

    // This block will be called by the client to get original implementation and call it.
    SentrySwizzleImpProvider originalImpProvider = ^IMP {
        // It's possible that another thread can call the method between the call to
        // class_replaceMethod and its return value being set.
        // So to be sure originalIMP has the right value, we need a lock.


        chooseLock(&lock);

        IMP imp = originalIMP;

        chooseUnlock(&lock);

        if (NULL == imp) {
            // If the class does not implement the method
            // we need to find an implementation in one of the superclasses.
            Class superclass = class_getSuperclass(classToSwizzle);
            imp = method_getImplementation(class_getInstanceMethod(superclass, selector));
        }
        return imp;
    };

    SentrySwizzleInfo *swizzleInfo = [SentrySwizzleInfo new];
    swizzleInfo.selector = selector;
    swizzleInfo.impProviderBlock = originalImpProvider;

    // We ask the client for the new implementation block.
    // We pass swizzleInfo as an argument to factory block, so the client can
    // call original implementation from the new implementation.
    id newIMPBlock = factoryBlock(swizzleInfo);

    const char *methodType = method_getTypeEncoding(method);

    IMP newIMP = imp_implementationWithBlock(newIMPBlock);

    // Atomically replace the original method with our new implementation.
    // This will ensure that if someone else's code on another thread is messing
    // with the class' method list too, we always have a valid method at all times.
    //
    // If the class does not implement the method itself then
    // class_replaceMethod returns NULL and superclasses's implementation will be used.
    //
    // We need a lock to be sure that originalIMP has the right value in the
    // originalImpProvider block above.

    chooseLock(&lock);

    originalIMP = class_replaceMethod(classToSwizzle, selector, newIMP, methodType);

    chooseUnlock(&lock);
}


static NSMutableDictionary *swizzledClassesDictionary() {
    static NSMutableDictionary *swizzledClasses;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        swizzledClasses = [NSMutableDictionary new];
    });
    return swizzledClasses;
}

static NSMutableSet *swizzledClassesForKey(const void *key) {
    NSMutableDictionary *classesDictionary = swizzledClassesDictionary();
    NSValue *keyValue = [NSValue valueWithPointer:key];
    NSMutableSet *swizzledClasses = [classesDictionary objectForKey:keyValue];
    if (!swizzledClasses) {
        swizzledClasses = [NSMutableSet new];
        [classesDictionary setObject:swizzledClasses forKey:keyValue];
    }
    return swizzledClasses;
}

+ (BOOL)swizzleInstanceMethod:(SEL)selector
                      inClass:(Class)classToSwizzle
                newImpFactory:(SentrySwizzleImpFactoryBlock)factoryBlock
                         mode:(SentrySwizzleMode)mode
                          key:(const void *)key {
    NSAssert(!(NULL == key && SentrySwizzleModeAlways != mode),
            @"Key may not be NULL if mode is not SentrySwizzleModeAlways.");

    @synchronized (swizzledClassesDictionary()) {
        if (key) {
            NSSet *swizzledClasses = swizzledClassesForKey(key);
            if (mode == SentrySwizzleModeOncePerClass) {
                if ([swizzledClasses containsObject:classToSwizzle]) {
                    return NO;
                }
            } else if (mode == SentrySwizzleModeOncePerClassAndSuperclasses) {
                for (Class currentClass = classToSwizzle;
                     nil != currentClass;
                     currentClass = class_getSuperclass(currentClass)) {
                    if ([swizzledClasses containsObject:currentClass]) {
                        return NO;
                    }
                }
            }
        }

        swizzle(classToSwizzle, selector, factoryBlock);

        if (key) {
            [swizzledClassesForKey(key) addObject:classToSwizzle];
        }
    }

    return YES;
}

+ (void)swizzleClassMethod:(SEL)selector
                   inClass:(Class)classToSwizzle
             newImpFactory:(SentrySwizzleImpFactoryBlock)factoryBlock {
    [self swizzleInstanceMethod:selector
                        inClass:object_getClass(classToSwizzle)
                  newImpFactory:factoryBlock
                           mode:SentrySwizzleModeAlways
                            key:NULL];
}

@end
