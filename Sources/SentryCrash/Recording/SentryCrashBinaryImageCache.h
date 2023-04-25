#ifndef SentryCrashBinaryImageCache_h
#define SentryCrashBinaryImageCache_h

#include "SentryCrashDynamicLinker.h"
#include <stdio.h>

typedef void (*sentrycrashbic_imageIteratorCallback)(SentryCrashBinaryImage *, void *context);

void sentrycrashbic_iterateOverImages(sentrycrashbic_imageIteratorCallback index, void *context);

/**
 * Startes the cache that will monitor binary image being loaded or removed.
 */
void sentrycrashbic_startCache(void);

/**
 * Stops the cache from monitor binary image being loaded or removed.
 * This will also clean the cache.
 */
void sentrycrashbic_stopCache(void);

#endif /* SentryCrashBinaryImageCache_h */
