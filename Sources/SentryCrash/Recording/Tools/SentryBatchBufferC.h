//
//  sentry_batch_buffer.h
//
//  Buffer wrapper for managing memory buffers.
//

#ifndef HDR_SENTRY_BATCH_BUFFER_H
#define HDR_SENTRY_BATCH_BUFFER_H

#include <stdbool.h>
#include <stddef.h>

typedef struct {
    char *data;
    size_t data_capacity;
    size_t data_size;

    size_t *item_offsets;
    size_t *item_sizes;

    size_t items_capacity;
    size_t item_count;
} SentryBatchBufferC;

/** @return true if initialization was successful, false otherwise.
 *
 * @note This function is NOT async-signal-safe because it calls malloc().
 */
bool sentry_batch_buffer_init(SentryBatchBufferC *buffer, size_t data_capacity, size_t max_items);

void sentry_batch_buffer_destroy(SentryBatchBufferC *buffer);

/** @return true if the item was successfully added, false if buffer is full. */
bool sentry_batch_buffer_add_item(SentryBatchBufferC *buffer, const char *data, size_t length);

/** @return A pointer to the item's data, or NULL if index is invalid. */
const char *sentry_batch_buffer_get_item(
    const SentryBatchBufferC *buffer, size_t index, size_t *size_out);

/** @return A pointer to the data buffer, or NULL if the buffer is empty. */
const char *sentry_batch_buffer_get_data(const SentryBatchBufferC *buffer);

size_t sentry_batch_buffer_get_data_size(const SentryBatchBufferC *buffer);

size_t sentry_batch_buffer_get_data_capacity(const SentryBatchBufferC *buffer);

void sentry_batch_buffer_clear(SentryBatchBufferC *buffer);

size_t sentry_batch_buffer_get_item_count(const SentryBatchBufferC *buffer);

#endif // HDR_SENTRY_BATCH_BUFFER_H
