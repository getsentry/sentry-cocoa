#ifndef SentryCrashBinaryImageCacheState_h
#define SentryCrashBinaryImageCacheState_h

#include "SentryCrashBinaryImageCache.h"
#include <mach-o/dyld.h>
#include <stdatomic.h>
#include <stdbool.h>
#include <stdint.h>

typedef void (*SentryRegisterImageCallback)(const struct mach_header *mh, intptr_t vmaddr_slide);
typedef void (*SentryRegisterFunction)(SentryRegisterImageCallback function);

#define SENTRYCRASHBIC_MAX_DYLD_IMAGES 4096

typedef struct {
    _Atomic(uint32_t) state;
    SentryCrashBinaryImage image;
} PublishedBinaryImage;

typedef struct SentryCrashBinaryImageCacheState {
    PublishedBinaryImage images[SENTRYCRASHBIC_MAX_DYLD_IMAGES];
    _Atomic(uint32_t) nextIndex;
    _Atomic(sentrycrashbic_cacheChangeCallback) addedCallback;
    _Atomic(sentrycrashbic_cacheChangeCallback) removedCallback;
    _Atomic(bool) trackingStarted;
    _Atomic(bool) didLogImageLimitReached;
    SentryRegisterFunction addImageCallback;
    SentryRegisterFunction removeImageCallback;
    void (*beforeAddImageCallback)(void);
} SentryCrashBinaryImageCacheState;

#endif /* SentryCrashBinaryImageCacheState_h */
