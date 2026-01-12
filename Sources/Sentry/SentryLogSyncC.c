#include "SentryLogSyncC.h"
#include <stdlib.h>

static SentryBatchBufferC *logBuffer = NULL;

bool
sentrycrash_logSync_start(size_t data_capacity, size_t items_capacity)
{
    // Clean up any existing buffer first
    sentrycrash_logSync_stop();

    logBuffer = (SentryBatchBufferC *)malloc(sizeof(SentryBatchBufferC));
    if (logBuffer == NULL) {
        return false;
    }

    if (!sentry_batch_buffer_init(logBuffer, data_capacity, items_capacity)) {
        free(logBuffer);
        logBuffer = NULL;
        return false;
    }

    return true;
}

void
sentrycrash_logSync_stop(void)
{
    if (logBuffer != NULL) {
        sentry_batch_buffer_destroy(logBuffer);
        free(logBuffer);
        logBuffer = NULL;
    }
}

SentryBatchBufferC *
sentrycrash_logSync_getBuffer(void)
{
    return logBuffer;
}
