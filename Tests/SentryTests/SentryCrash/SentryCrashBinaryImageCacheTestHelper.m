#import "SentryCrashBinaryImageCacheTestHelper.h"
#import "SentryCrashBinaryImageCacheState.h"

#include <string.h>

static SentryCrashBinaryImageCacheState test_cache_state;

static void
initializeTestCacheState(SentryCrashBinaryImageCacheState *cache)
{
    memset(cache, 0, sizeof(*cache));
    cache->addImageCallback = &_dyld_register_func_for_add_image;
    cache->removeImageCallback = &_dyld_register_func_for_remove_image;
}

void
sentrycrashbic_useFreshTestCacheState(void)
{
    initializeTestCacheState(&test_cache_state);
    sentrycrashbic_setActiveCacheState(&test_cache_state);
}

void
sentrycrashbic_useDefaultCacheState(void)
{
    sentrycrashbic_setActiveCacheState(NULL);
}
