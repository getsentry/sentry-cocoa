#ifndef SentryCrashBinaryImageCache_h
#define SentryCrashBinaryImageCache_h

#include "SentryCrashDynamicLinker.h"
#include <stdio.h>

/**
 *Get the number of loaded binary images.
 *
 *@warning This function is not thread safe, because this is meant to be used during crash signal
 *handling.
 */
int sentrycrashbic_imageCount(void);

/**
 * Return a pointer to a SentryCrashBinaryImage in the index position in the cache.
 *
 *@warning This function is not thread safe, because this is meant to be used during crash signal
 *handling.
 */
SentryCrashBinaryImage *sentrycrashbic_getBinaryImageCache(int index);

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
