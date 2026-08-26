#include "SentryFileIO.h"

#include "SentryAsyncSafeLog.h"
#include <errno.h>
#include <unistd.h>

bool
sentryFileIO_writeBytesToFD(const int fd, const void *const bytes, size_t length)
{
    const char *position = bytes;
    while (length > 0) {
        const ssize_t bytesWritten = write(fd, position, length);
        if (bytesWritten < 0) {
            if (errno == EINTR) {
                continue;
            }
            SENTRY_ASYNC_SAFE_LOG_ERROR(
                "Could not write to fd %d: %s", fd, SENTRY_STRERROR_R(errno));
            return false;
        }
        if (bytesWritten == 0) {
            SENTRY_ASYNC_SAFE_LOG_ERROR("Could not write to fd %d: write returned zero bytes", fd);
            return false;
        }
        length -= (size_t)bytesWritten;
        position += bytesWritten;
    }
    return true;
}

bool
sentryFileIO_readBytesFromFD(const int fd, void *const bytes, size_t length)
{
    char *position = bytes;
    while (length > 0) {
        const ssize_t bytesRead = read(fd, position, length);
        if (bytesRead < 0) {
            if (errno == EINTR) {
                continue;
            }
            SENTRY_ASYNC_SAFE_LOG_ERROR(
                "Could not read from fd %d: %s", fd, SENTRY_STRERROR_R(errno));
            return false;
        }
        if (bytesRead == 0) {
            SENTRY_ASYNC_SAFE_LOG_ERROR(
                "Unexpected EOF on fd %d: expected %zu more bytes", fd, length);
            return false;
        }
        length -= (size_t)bytesRead;
        position += bytesRead;
    }
    return true;
}
