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
 * Starts the cache that will monitor binary image being loaded or removed.
 */
void sentrycrashbic_startCache(void);

/**
 * This is a no-op TODO: Remove this
 */
void sentrycrashbic_stopCache(void);

/**
 * Register a callback to be called every time a new binary image is added to the cache.
 * After register, this callback will be called for every image already in the cache,
 * this is a thread safe operation. The callback can be called multiple times for the same image
 * If the image was being registered on a different thread at the same time the callback is registered.
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
