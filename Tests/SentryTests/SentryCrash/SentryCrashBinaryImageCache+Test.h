#ifndef SentryCrashBinaryImageCache_Test_h
#define SentryCrashBinaryImageCache_Test_h

#include "SentryCrashBinaryImageCache.h"
#include <mach-o/dyld.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#if defined(SENTRY_TEST) || defined(SENTRY_TEST_CI) || defined(DEBUG)

typedef void (*SentryRegisterImageCallback)(const struct mach_header *mh, intptr_t vmaddr_slide);
typedef void (*SentryRegisterFunction)(SentryRegisterImageCallback function);

/** Overrides the dyld add-image registration function for the active test cache state. */
void sentrycrashbic_setRegisterFuncForAddImage(SentryRegisterFunction addFunction);

/** Overrides the dyld remove-image registration function for the active test cache state. */
void sentrycrashbic_setRegisterFuncForRemoveImage(SentryRegisterFunction removeFunction);

/** Installs a callback that runs immediately before an image is added to the cache. */
void sentrycrashbic_setBeforeAddImageCallback(void (*callback)(void));

#endif

#if defined(SENTRY_TEST) || defined(SENTRY_TEST_CI)

/** Resets and activates the dedicated test cache state. */
void sentrycrashbic_useFreshTestCacheState(void);

/** Restores the default cache state after a test finishes. */
void sentrycrashbic_useDefaultCacheState(void);

#endif

#ifdef __cplusplus
}
#endif

#endif /* SentryCrashBinaryImageCache_Test_h */
