#include "SentryKSCrashScopeBuffer.h"
#include <os/lock.h>
#include <stdatomic.h>
#include <stdlib.h>
#include <string.h>

static _Atomic(const char *) g_scopeJSON = NULL;
static os_unfair_lock g_lock = OS_UNFAIR_LOCK_INIT;

void
sentryKSCrash_setScopeJSON(const char *json)
{
    const char *newPtr = json ? strdup(json) : NULL;
    if (json != NULL && newPtr == NULL) {
        // strdup failed; retain the existing scope JSON
        return;
    }
    os_unfair_lock_lock(&g_lock);
    const char *old
        = atomic_load_explicit((_Atomic(const char *) *)&g_scopeJSON, memory_order_relaxed);
    atomic_store_explicit((_Atomic(const char *) *)&g_scopeJSON, newPtr, memory_order_release);
    os_unfair_lock_unlock(&g_lock);
    free((void *)old);
}

const char *
sentryKSCrash_getScopeJSON(void)
{
    return atomic_load_explicit((_Atomic(const char *) *)&g_scopeJSON, memory_order_acquire);
}
