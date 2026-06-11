#import "CrashE2EObjCBridge.h"

#include <cxxabi.h>
#include <dlfcn.h>
#include <fcntl.h>
#include <mach-o/dyld.h>
#include <new>
#include <signal.h>
#include <stdexcept>
#include <stdlib.h>
#include <string.h>
#include <typeinfo>
#include <unistd.h>

@interface CrashE2EThrownObject : NSObject
@end

@implementation CrashE2EThrownObject
@end

using sentry_cxa_throw_type = void (*)(void *, std::type_info *, void (*)(void *));
using dynamic_image_call_type = void (*)(void (*)(void));
using dynamic_image_crash_type = void (*)(void);

static dynamic_image_call_type g_beforeDynamicImageCall = nullptr;
static dynamic_image_crash_type g_afterDynamicImageCrash = nullptr;

static NSString *
CrashE2EFindLoadedImage(const char *path)
{
    const char *lastPathComponent = strrchr(path, '/');
    lastPathComponent = lastPathComponent == nullptr ? path : lastPathComponent + 1;

    uint32_t imageCount = _dyld_image_count();
    for (uint32_t imageIndex = 0; imageIndex < imageCount; imageIndex++) {
        const char *imageName = _dyld_get_image_name(imageIndex);
        if (imageName == nullptr) {
            continue;
        }
        const char *imageLastPathComponent = strrchr(imageName, '/');
        imageLastPathComponent
            = imageLastPathComponent == nullptr ? imageName : imageLastPathComponent + 1;
        if (strcmp(imageName, path) == 0
            || strcmp(imageLastPathComponent, lastPathComponent) == 0) {
            return [NSString stringWithUTF8String:imageName];
        }
    }
    return nil;
}

extern "C" NSString *_Nullable CrashE2ELoadDynamicBinaryImage(const char *path, int slot)
{
    if (path == nullptr) {
        return nil;
    }

    void *handle = dlopen(path, RTLD_LAZY | RTLD_LOCAL);
    if (handle == nullptr) {
        NSLog(@"CrashE2E - failed to dlopen dynamic binary image %s: %s", path, dlerror());
        return nil;
    }

    if (slot == 0) {
        auto call
            = reinterpret_cast<dynamic_image_call_type>(dlsym(handle, "CrashE2EDynamicImageCall"));
        if (call == nullptr) {
            NSLog(
                @"CrashE2E - failed to dlsym CrashE2EDynamicImageCall in %s: %s", path, dlerror());
            return nil;
        }
        g_beforeDynamicImageCall = call;
    } else {
        auto crash = reinterpret_cast<dynamic_image_crash_type>(
            dlsym(handle, "CrashE2EDynamicImageCrash"));
        if (crash == nullptr) {
            NSLog(
                @"CrashE2E - failed to dlsym CrashE2EDynamicImageCrash in %s: %s", path, dlerror());
            return nil;
        }
        g_afterDynamicImageCrash = crash;
    }

    NSString *loadedImage = CrashE2EFindLoadedImage(path);
    if (loadedImage == nil) {
        NSLog(@"CrashE2E - dlopen succeeded but dyld image was not found: %s", path);
    }
    return loadedImage;
}

__attribute__((noinline, disable_tail_calls)) static void
CrashE2ECallAfterDynamicImage(void)
{
    g_afterDynamicImageCrash();
    __builtin_unreachable();
}

extern "C" __attribute__((noinline, disable_tail_calls)) void
CrashE2ETriggerDynamicBinaryImageCrash(void)
{
    if (g_beforeDynamicImageCall == nullptr || g_afterDynamicImageCrash == nullptr) {
        NSLog(@"CrashE2E - dynamic binary image call functions are not loaded");
        abort();
    }
    g_beforeDynamicImageCall(CrashE2ECallAfterDynamicImage);
    __builtin_unreachable();
}

static void
CrashE2EDestroyRuntimeError(void *exception)
{
    reinterpret_cast<std::runtime_error *>(exception)->~runtime_error();
}

static int g_managedRuntimeMarkerFD = -1;
static struct sigaction g_previousManagedRuntimeSignalAction;
static struct sigaction g_defaultManagedRuntimeSignalAction;

static void
CrashE2EFakeManagedRuntimeSignalHandler(int signal, siginfo_t *info, void *context)
{
    static const char marker[] = "CrashE2EFakeManagedRuntimeSignalHandler\n";
    if (g_managedRuntimeMarkerFD >= 0) {
        ssize_t bytesWritten = write(g_managedRuntimeMarkerFD, marker, sizeof(marker) - 1);
        (void)bytesWritten;
    }

    // The intended chain is managed runtime -> SentryCrash/KSCrash -> system. This fake handler
    // stands in for .NET/Mono after SentryCrash's preload constructor has installed the early
    // signal handler. Recoverable managed faults are intentionally out of scope: with the correct
    // order, the managed runtime handles them without ever calling Sentry. This handler forwards
    // only to smoke-test the unrecoverable path where the runtime delegates to its previous
    // handler. Resetting to the default action before forwarding keeps Sentry's final re-raise from
    // re-entering this fake managed handler.
    sigaction(signal, &g_defaultManagedRuntimeSignalAction, NULL);

    if ((g_previousManagedRuntimeSignalAction.sa_flags & SA_SIGINFO) != 0
        && g_previousManagedRuntimeSignalAction.sa_sigaction != NULL) {
        g_previousManagedRuntimeSignalAction.sa_sigaction(signal, info, context);
    } else if (g_previousManagedRuntimeSignalAction.sa_handler != NULL
        && g_previousManagedRuntimeSignalAction.sa_handler != SIG_DFL
        && g_previousManagedRuntimeSignalAction.sa_handler != SIG_IGN) {
        g_previousManagedRuntimeSignalAction.sa_handler(signal);
    }

    raise(signal);
    __builtin_unreachable();
}

extern "C" void
CrashE2EInstallFakeManagedRuntimeSignalHandler(const char *markerPath)
{
    if (markerPath == NULL) {
        NSLog(@"CrashE2E - missing fake managed runtime handler marker path");
        abort();
    }

    g_managedRuntimeMarkerFD = open(markerPath, O_CREAT | O_WRONLY | O_TRUNC, 0600);
    if (g_managedRuntimeMarkerFD < 0) {
        NSLog(@"CrashE2E - failed to open fake managed runtime handler marker: %s", markerPath);
        abort();
    }

    sigemptyset(&g_defaultManagedRuntimeSignalAction.sa_mask);
    g_defaultManagedRuntimeSignalAction.sa_handler = SIG_DFL;

    struct sigaction action = { };
    sigemptyset(&action.sa_mask);
    action.sa_flags = SA_SIGINFO | SA_ONSTACK;
#ifdef SA_64REGSET
    action.sa_flags |= SA_64REGSET;
#endif
    action.sa_sigaction = CrashE2EFakeManagedRuntimeSignalHandler;

    if (sigaction(SIGSEGV, &action, &g_previousManagedRuntimeSignalAction) != 0) {
        NSLog(@"CrashE2E - failed to install fake managed runtime signal handler");
        abort();
    }
}

extern "C" void
CrashE2ETriggerCPPException(void)
{
    throw std::runtime_error("CrashE2ECPPException");
}

extern "C" void
CrashE2ETriggerUnitySentryCxaThrow(void)
{
    // This intentionally simulates Sentry Unity's native iOS C++ ABI shim rather
    // than an arbitrary alternate throw helper. That shim exports weak __cxa_throw/__cxa_rethrow
    // wrappers and, when entered, first probes Sentry Cocoa's explicitly named __sentry_cxa_throw
    // / __sentry_cxa_rethrow symbols before falling back to RTLD_NEXT. The Sentry-named symbols
    // give the shim an unambiguous handoff target; otherwise it only sees the generic __cxa_throw
    // name, which may refer to itself, Sentry Cocoa, libc++abi, or another interposer depending on
    // symbol resolution order. Calling the named symbol here validates the Sentry Cocoa side of
    // that chaining contract without asserting crash-backend internals.
    //
    // The scenario intentionally runs with Sentry Cocoa's C++ V2 option disabled because Sentry
    // Unity does not enable that option today. This means current SentryCrash reports inherit the
    // legacy/V1 monitor's missing-crashed-thread caveats. Those caveats are not KSCrash parity
    // requirements; the migration must preserve the Sentry-named symbols, not the V1 report shape.
    auto sentryCxaThrow
        = reinterpret_cast<sentry_cxa_throw_type>(dlsym(RTLD_DEFAULT, "__sentry_cxa_throw"));
    if (sentryCxaThrow == nullptr) {
        NSLog(@"CrashE2E - failed to resolve __sentry_cxa_throw");
        abort();
    }

    void *exception = __cxxabiv1::__cxa_allocate_exception(sizeof(std::runtime_error));
    new (exception) std::runtime_error("CrashE2EUnitySentryCxaThrowException");
    sentryCxaThrow(exception, const_cast<std::type_info *>(&typeid(std::runtime_error)),
        CrashE2EDestroyRuntimeError);
    abort();
}

extern "C" void
CrashE2ETriggerObjCObjectException(void)
{
    @throw [[CrashE2EThrownObject alloc] init];
}
