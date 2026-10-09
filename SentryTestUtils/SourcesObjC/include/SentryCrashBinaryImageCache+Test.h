#ifndef SentryCrashBinaryImageCache_Test_h
#define SentryCrashBinaryImageCache_Test_h

#if !SDK_V10

#    include "SentryCrashBinaryImageCache.h"

#    ifdef __cplusplus
extern "C" {
#    endif

typedef struct SentryCrashBinaryImageCacheState SentryCrashBinaryImageCacheState;

/** Activates a caller-owned cache state for tests. Pass NULL to restore the default state. */
void sentrycrashbic_setActiveCacheState(SentryCrashBinaryImageCacheState *cache);

#    ifdef __cplusplus
}
#    endif

#endif // !SDK_V10

#endif /* SentryCrashBinaryImageCache_Test_h */
