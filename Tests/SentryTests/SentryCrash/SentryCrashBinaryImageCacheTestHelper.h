#ifndef SentryCrashBinaryImageCacheTestHelper_h
#define SentryCrashBinaryImageCacheTestHelper_h

#include "SentryCrashBinaryImageCache+Test.h"

#ifdef __cplusplus
extern "C" {
#endif

void sentrycrashbic_useFreshTestCacheState(void);
void sentrycrashbic_useDefaultCacheState(void);

#ifdef __cplusplus
}
#endif

#endif /* SentryCrashBinaryImageCacheTestHelper_h */
