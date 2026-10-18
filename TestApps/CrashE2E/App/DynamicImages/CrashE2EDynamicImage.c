#include <stdint.h>

typedef void (*CrashE2EDynamicImageCallback)(void);

static volatile uint64_t g_crashE2EDynamicImageSink;

__attribute__((noinline, disable_tail_calls, visibility("default"))) void
CrashE2EDynamicImageCall(CrashE2EDynamicImageCallback callback)
{
    callback();
    g_crashE2EDynamicImageSink++;
}

__attribute__((noinline, disable_tail_calls, visibility("default"))) void
CrashE2EDynamicImageCrash(void)
{
    volatile int *invalidAddress = (int *)0;
    *invalidAddress = 1;
    __builtin_unreachable();
}

__attribute__((visibility("default"))) uint64_t
CrashE2EDynamicImageMarker(void)
{
#if CRASH_E2E_DYNAMIC_IMAGE_AFTER
    return 0xC2A5E2EAULL;
#else
    return 0xC2A5E2EBULL;
#endif
}
