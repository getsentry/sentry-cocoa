#ifndef SentryKSCrashManagedSignal_h
#define SentryKSCrashManagedSignal_h

#if SDK_V10

#    include "KSCrashMonitorAPI.h"
#    include <stdbool.h>
#    include <stdint.h>

#    ifdef __cplusplus
extern "C" {
#    endif

/** Whether this binary was compiled for managed-runtime signal interop. */
bool sentrykscrash_isManagedRuntimeBuild(void);

/** Mach exceptions retained by managed-runtime builds; excludes faults converted by Mono/.NET. */
uint32_t sentrykscrash_managedMachExceptionMask(void);

/** The replacement Signal monitor used by managed-runtime builds. */
KSCrashMonitorAPI *_Nonnull sentrykscrash_managedSignalMonitorAPI(void);

/** Consume the next delivery's token on this thread, suppressing its report only if it matches. */
void sentrykscrash_ignoreNextSignal(int signal);

#    ifdef __cplusplus
}
#    endif

#endif // SDK_V10

#endif /* SentryKSCrashManagedSignal_h */
