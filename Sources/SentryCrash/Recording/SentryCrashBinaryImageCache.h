#ifndef SentryCrashBinaryImageCache_h
#define SentryCrashBinaryImageCache_h

#include <stdio.h>
#include "SentryCrashDynamicLinker.h"

/**
 *Get the number of loaded binary images.
 */
int sentrycrashbic_imageCount(void);

/**
 * Return a pointer to a SentryCrashBinaryImage in the index position in the cache.
 */
SentryCrashBinaryImage * sentrycrashbic_getBinaryImageBuffer(int index);

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
