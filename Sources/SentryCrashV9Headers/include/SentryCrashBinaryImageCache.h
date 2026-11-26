#ifndef SentryCrashBinaryImageCache_h
#define SentryCrashBinaryImageCache_h

#include "SentryCrashDynamicLinker.h"
#include <stdio.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef void (*sentrycrashbic_imageIteratorCallback)(SentryCrashBinaryImage *, void *context);

typedef void (*sentrycrashbic_cacheChangeCallback)(const SentryCrashBinaryImage *binaryImage);

void sentrycrashbic_iterateOverImages(sentrycrashbic_imageIteratorCallback index, void *context);

/**
 * Starts the cache that monitors binary images being loaded or removed.
 * The expensive dyld bootstrap is scheduled only once for the lifetime of the process.
 */
void sentrycrashbic_startCache(void);

/**
 * Disconnects higher-level consumers from the binary image cache.
 * Once the canonical C cache has been bootstrapped it keeps tracking loaded images so
 * crashes can still be symbolicated across stop/start cycles.
 */
void sentrycrashbic_stopCache(void);

/**
 * Register a callback to be called every time a new binary image is added to the cache.
 * After register, this callback will be called for every image already in the cache,
 * this is a thread safe operation.
 */
void sentrycrashbic_registerAddedCallback(sentrycrashbic_cacheChangeCallback callback);

/**
 * Register a callback to be called every time a binary image is remove from the cache.
 */
void sentrycrashbic_registerRemovedCallback(sentrycrashbic_cacheChangeCallback callback);

#ifdef __cplusplus
}
#endif

#endif /* SentryCrashBinaryImageCache_h */
