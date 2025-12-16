//
//  sentry_batch_buffer.h
//
//  Buffer wrapper for managing memory buffers.
//

#ifndef HDR_SENTRY_BATCH_BUFFER_H
#define HDR_SENTRY_BATCH_BUFFER_H

#include <stdbool.h>
#include <stddef.h>

/** Buffer structure. Everything inside should be considered internal use only. */
typedef struct {
    char *data;
    size_t data_capacity;
    size_t data_size;
    size_t item_count;
} SentryBatchBuffer;

/** Initialize a batch buffer.
 *
 * @param buffer The buffer to initialize.
 * @param capacity The capacity of the buffer in bytes.
 * @return true if initialization was successful, false otherwise.
 *
 * @note This function is NOT async-signal-safe because it calls malloc().
 *       The buffer must be pre-allocated before installing signal handlers
 *       if it will be used from within signal handlers.
 */
bool sentry_batch_buffer_init(SentryBatchBuffer *buffer, size_t capacity);

/** Destroy a buffer and free its resources.
 *
 * @param buffer The buffer to destroy.
 */
void sentry_batch_buffer_destroy(SentryBatchBuffer *buffer);

/** Add an item to the buffer. Automatically adds a comma separator before
 * the item if it's not the first item, and increments the item count.
 *
 * @param buffer The buffer to add the item to.
 * @param data The data of the item to add.
 * @param length The length of the data to add.
 * @return true if the item was successfully added.
 */
bool sentry_batch_buffer_add_item(SentryBatchBuffer *buffer, const char *data, size_t length);

/** Get a pointer to the buffer's data.
 *
 * @param buffer The buffer.
 * @return A pointer to the buffer's data, or NULL if the buffer is empty.
 */
const char *sentry_batch_buffer_get_data(const SentryBatchBuffer *buffer);

/** Get the current data size of the buffer.
 *
 * @param buffer The buffer.
 * @return The current data size in bytes (number of bytes currently stored).
 */
size_t sentry_batch_buffer_get_data_size(const SentryBatchBuffer *buffer);

/** Get the current data capacity of the buffer.
 *
 * @param buffer The buffer.
 * @return The current data capacity of the buffer.
 */
size_t sentry_batch_buffer_get_data_capacity(const SentryBatchBuffer *buffer);

/** Clear the buffer, resetting data_size to zero.
 *
 * @param buffer The buffer to clear.
 */
void sentry_batch_buffer_clear(SentryBatchBuffer *buffer);

/** Get the current item count in the buffer.
 *
 * @param buffer The buffer.
 * @return The current item count.
 */
size_t sentry_batch_buffer_get_item_count(const SentryBatchBuffer *buffer);

#endif // HDR_SENTRY_BATCH_BUFFER_H
