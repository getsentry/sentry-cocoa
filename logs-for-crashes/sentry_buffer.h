//
//  sentry_buffer.h
//
//  Buffer wrapper for managing memory buffers.
//

#ifndef HDR_SENTRY_BUFFER_H
#define HDR_SENTRY_BUFFER_H

#include <stdbool.h>
#include <stddef.h>

/** Buffer structure. Everything inside should be considered internal use only. */
typedef struct {
    char *data;
    size_t capacity;
    size_t length;
} SentryBuffer;

bool sentry_buffer_init(SentryBuffer *buffer, size_t capacity);

/** Destroy a buffer and free its resources.
 *
 * @param buffer The buffer to destroy.
 */
void sentry_buffer_destroy(SentryBuffer *buffer);

/** Write data to the buffer.
 *
 * @param buffer The buffer to write to.
 * @param data The data to write.
 * @param length The length of the data to write.
 * @return true if the data was successfully written.
 */
bool sentry_buffer_write(SentryBuffer *buffer, const char *data, size_t length);

/** Get a pointer to the buffer's data.
 *
 * @param buffer The buffer.
 * @return A pointer to the buffer's data, or NULL if the buffer is empty.
 */
const char *sentry_buffer_get_data(const SentryBuffer *buffer);

/** Get the current length of the buffer.
 *
 * @param buffer The buffer.
 * @return The current length of the buffer.
 */
size_t sentry_buffer_get_length(const SentryBuffer *buffer);

/** Get the current capacity of the buffer.
 *
 * @param buffer The buffer.
 * @return The current capacity of the buffer.
 */
size_t sentry_buffer_get_capacity(const SentryBuffer *buffer);

/** Clear the buffer, resetting length to zero.
 *
 * @param buffer The buffer to clear.
 */
void sentry_buffer_clear(SentryBuffer *buffer);

#endif // HDR_SENTRY_BUFFER_H
