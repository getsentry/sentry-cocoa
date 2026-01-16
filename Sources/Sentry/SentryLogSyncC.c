#include "SentryLogSyncC.h"
#include "SentryAsyncSafeLog.h"
#include <SentryCrashFileUtils.h>
#include <errno.h>
#include <fcntl.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static SentryBatchBufferC *logBuffer = NULL;
static char *logFilePath = NULL;

bool
sentryLogSync_start(size_t data_capacity, size_t items_capacity)
{
    // Clean up any existing buffer first
    sentryLogSync_stop();

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
sentryLogSync_stop(void)
{
    if (logBuffer != NULL) {
        sentry_batch_buffer_destroy(logBuffer);
        free(logBuffer);
        logBuffer = NULL;
    }

    if (logFilePath != NULL) {
        free(logFilePath);
        logFilePath = NULL;
    }
}

SentryBatchBufferC *
sentryLogSync_getBuffer(void)
{
    return logBuffer;
}

void
sentryLogSync_setPath(const char *path)
{
    if (logFilePath != NULL) {
        free(logFilePath);
        logFilePath = NULL;
    }

    if (path == NULL) {
        return;
    }

    size_t pathLen = strlen(path) + 1; // Add a byte for the null-terminator.
    logFilePath = malloc(pathLen);
    if (logFilePath != NULL) {
        strlcpy(logFilePath, path, pathLen);
    }
}

void
sentryLogSync_writeToFile(void)
{
    if (logBuffer == NULL || logFilePath == NULL) {
        return;
    }

    size_t itemCount = logBuffer->item_count;
    if (itemCount == 0) {
        return;
    }

    int fd = open(logFilePath, O_RDWR | O_CREAT | O_TRUNC, 0644);
    if (fd < 0) {
        SENTRY_ASYNC_SAFE_LOG_ERROR(
            "Could not open log file for crash: %s", SENTRY_STRERROR_R(errno));
        return;
    }

    // Write JSON structure: {"items":[<item1>,<item2>,...]}
    // Items are already JSON-encoded SentryLog objects
    static const char jsonStart[] = "{\"items\":[";
    static const char jsonEnd[] = "]}";
    static const char jsonSeparator[] = ",";

    if (!sentrycrashfu_writeBytesToFD(fd, jsonStart, (int)(sizeof(jsonStart) - 1))) {
        SENTRY_ASYNC_SAFE_LOG_ERROR("Error writing JSON start for crash logs.");
        close(fd);
        return;
    }

    for (size_t i = 0; i < itemCount; i++) {
        // Write comma separator between items (not before first item)
        if (i > 0) {
            if (!sentrycrashfu_writeBytesToFD(
                    fd, jsonSeparator, (int)(sizeof(jsonSeparator) - 1))) {
                SENTRY_ASYNC_SAFE_LOG_ERROR("Error writing JSON separator for crash logs.");
                break;
            }
        }

        size_t itemSize = logBuffer->item_sizes[i];
        const char *itemData = logBuffer->data + logBuffer->item_offsets[i];

        if (!sentrycrashfu_writeBytesToFD(fd, itemData, (int)itemSize)) {
            SENTRY_ASYNC_SAFE_LOG_ERROR("Error writing log item data for crash.");
            break;
        }
    }

    sentrycrashfu_writeBytesToFD(fd, jsonEnd, (int)(sizeof(jsonEnd) - 1));

    close(fd);
}
