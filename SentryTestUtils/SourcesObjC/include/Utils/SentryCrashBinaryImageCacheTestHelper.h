#ifndef SentryCrashBinaryImageCacheTestHelper_h
#define SentryCrashBinaryImageCacheTestHelper_h

#if !SDK_V10

#    include "Wrappers/SentryCrashBinaryImageCacheWrapper.h"

#    ifdef __cplusplus
extern "C" {
#    endif

void sentrycrashbic_useFreshTestCacheState(void);
void sentrycrashbic_useDefaultCacheState(void);

#    ifdef __cplusplus
}
#    endif

#endif // !SDK_V10

#endif /* SentryCrashBinaryImageCacheTestHelper_h */
