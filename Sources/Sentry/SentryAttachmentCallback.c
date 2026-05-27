#include "SentryAttachmentCallback.h"
#include <stdbool.h>
#include <stddef.h>

// Stub implementations — the SentryCrash C attachment hook mechanism is not
// available in upstream KSCrash v2. Screenshot and view-hierarchy captures
// during crashes require a KSCrash-native solution (e.g. didWriteReportCallback).
// These stubs keep the linker happy while that work is pending.

static SaveAttachmentCallback g_saveScreenshots = NULL;
static SaveAttachmentCallback g_saveViewHierarchy = NULL;

void
sentrycrash_setSaveScreenshots(SaveAttachmentCallback callback)
{
    g_saveScreenshots = callback;
}

void
sentrycrash_setSaveViewHierarchy(SaveAttachmentCallback callback)
{
    g_saveViewHierarchy = callback;
}

bool
sentrycrash_hasSaveScreenshotCallback(void)
{
    return g_saveScreenshots != NULL;
}

bool
sentrycrash_hasSaveViewHierarchyCallback(void)
{
    return g_saveViewHierarchy != NULL;
}
