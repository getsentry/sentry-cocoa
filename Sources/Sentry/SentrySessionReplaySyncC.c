#include "SentrySessionReplaySyncC.h"
#include "SentryAsyncSafeLog.h"
#include "SentryFileIO.h"
#include <errno.h>
#include <fcntl.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

static SentryCrashReplay crashReplay = { 0 };

void
sentrySessionReplaySync_start(const char *const path, unsigned int replayType)
{
    SENTRY_ASYNC_SAFE_LOG_DEBUG("[Session Replay] Starting session replay with path: %s", path);
    crashReplay.lastSegmentEnd = 0;
    crashReplay.segmentId = 0;
    crashReplay.replayType = replayType;

    if (crashReplay.path != NULL) {
        free(crashReplay.path);
    }

    // strlen here cannot read out of bounds: path is the C-string contract of this public C
    // entry point. Callers are NSString/Swift String bridges that emit null-terminated UTF-8.
    size_t buffer_size = sizeof(char) * (strlen(path) + 1); // Add a byte for the null-terminator.
    crashReplay.path = malloc(buffer_size);

    if (crashReplay.path == NULL) {
        SENTRY_ASYNC_SAFE_LOG_ERROR(
            "Failed to allocate memory for crash replay path. File path: %s", path);
        return;
    }

    strlcpy(crashReplay.path, path, buffer_size);
}

void
sentrySessionReplaySync_updateInfo(unsigned int segmentId, double lastSegmentEnd)
{
    SENTRY_ASYNC_SAFE_LOG_DEBUG(
        "[Session Replay] Updating session info with segmentId: %u, lastSegmentEnd: %f", segmentId,
        lastSegmentEnd);
    crashReplay.segmentId = segmentId;
    crashReplay.lastSegmentEnd = lastSegmentEnd;
}

void
sentrySessionReplaySync_updateReplayType(unsigned int replayType)
{
    crashReplay.replayType = replayType;
}

void
sentrySessionReplaySync_writeInfo(void)
{
    SENTRY_ASYNC_SAFE_LOG_DEBUG("[Session Replay] Writing session info");
    if (crashReplay.path == NULL) {
        SENTRY_ASYNC_SAFE_LOG_ERROR("There is no path to write replay information");
        return;
    }

    int fd = open(crashReplay.path, O_RDWR | O_CREAT | O_TRUNC, 0644);

    if (fd < 1) {
        SENTRY_ASYNC_SAFE_LOG_ERROR("Could not open replay info crash for file %s: %s",
            crashReplay.path, SENTRY_STRERROR_R(errno));
        return;
    }

    if (!sentryFileIO_writeBytesToFD(fd, &crashReplay.segmentId, sizeof(crashReplay.segmentId))) {
        SENTRY_ASYNC_SAFE_LOG_ERROR("Error writing replay info for crash.");
        close(fd);
        return;
    }

    if (!sentryFileIO_writeBytesToFD(
            fd, &crashReplay.lastSegmentEnd, sizeof(crashReplay.lastSegmentEnd))) {
        SENTRY_ASYNC_SAFE_LOG_ERROR("Error writing replay info for crash.");
        close(fd);
        return;
    }

    if (!sentryFileIO_writeBytesToFD(fd, &crashReplay.replayType, sizeof(crashReplay.replayType))) {
        SENTRY_ASYNC_SAFE_LOG_ERROR("Error writing replay type for crash.");
        close(fd);
        return;
    }

    close(fd);
}

bool
sentrySessionReplaySync_readInfo(SentryCrashReplay *output, const char *const path)
{
    SENTRY_ASYNC_SAFE_LOG_DEBUG("[Session Replay] Reading session info from path: %s", path);
    int fd = open(path, O_RDONLY);
    if (fd < 0) {
        SENTRY_ASYNC_SAFE_LOG_ERROR(
            "Could not open replay info crash file %s: %s", path, SENTRY_STRERROR_R(errno));
        return false;
    }

    unsigned int segmentId = 0;
    double lastSegmentEnd = 0;
    unsigned int replayType = 0;

    if (!sentryFileIO_readBytesFromFD(fd, &segmentId, sizeof(segmentId))) {
        SENTRY_ASYNC_SAFE_LOG_ERROR("Error reading segmentId from replay info crash file.");
        close(fd);
        return false;
    }

    if (!sentryFileIO_readBytesFromFD(fd, &lastSegmentEnd, sizeof(lastSegmentEnd))) {
        SENTRY_ASYNC_SAFE_LOG_ERROR("Error reading lastSegmentEnd from replay info crash file.");
        close(fd);
        return false;
    }

    struct stat fileInfo;
    const off_t replayTypeEndOffset
        = (off_t)(sizeof(segmentId) + sizeof(lastSegmentEnd) + sizeof(replayType));
    // Replay type was appended to the file format, so older files end after lastSegmentEnd.
    if (fstat(fd, &fileInfo) == 0 && fileInfo.st_size >= replayTypeEndOffset
        && !sentryFileIO_readBytesFromFD(fd, &replayType, sizeof(replayType))) {
        SENTRY_ASYNC_SAFE_LOG_ERROR("Error reading replay type from replay info crash file.");
        close(fd);
        return false;
    }

    close(fd);

    output->segmentId = segmentId;
    output->lastSegmentEnd = lastSegmentEnd;
    output->replayType = replayType;
    return lastSegmentEnd != 0 || replayType != 0;
}
