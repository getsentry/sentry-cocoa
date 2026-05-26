#include "SentryKSCrashScopeBuffer.h"
#include <os/lock.h>
#include <stdlib.h>
#include <string.h>

static const char *g_scopeJSON = NULL;
static os_unfair_lock g_lock = OS_UNFAIR_LOCK_INIT;

void
sentryKSCrash_setScopeJSON(const char *json)
{
    os_unfair_lock_lock(&g_lock);
    const char *old = g_scopeJSON;
    g_scopeJSON = json ? strdup(json) : NULL;
    os_unfair_lock_unlock(&g_lock);
    free((void *)old);
}

const char *
sentryKSCrash_getScopeJSON(void)
{
    return g_scopeJSON;
}
