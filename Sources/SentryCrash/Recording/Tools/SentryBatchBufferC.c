//
//  sentry_batch_buffer.c
//
//  Buffer wrapper for managing memory buffers.
//

#include "SentryBatchBufferC.h"
#include <stdlib.h>
#include <string.h>

static const char JSON_EMPTY_PAYLOAD[] = "{\"items\":[]}";
static const size_t JSON_EMPTY_PAYLOAD_SIZE = 12;

static const char JSON_SUFFIX[] = "]}";
static const size_t JSON_SUFFIX_SIZE = 2;

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
bool
sentry_batch_buffer_init(SentryBatchBuffer *buffer, size_t capacity)
{
    if (buffer == NULL) {
        return false;
    }

    buffer->data = NULL;
    buffer->data_capacity = 0;
    buffer->data_size = 0;
    buffer->item_count = 0;

    if (capacity == 0) {
        return true;
    }

    buffer->data = (char *)malloc(capacity);
    if (buffer->data == NULL) {
        return false;
    }

    buffer->data_capacity = capacity;

    // Initialize with empty JSON payload
    if (capacity < JSON_EMPTY_PAYLOAD_SIZE) {
        free(buffer->data);
        buffer->data = NULL;
        buffer->data_capacity = 0;
        return false;
    }

    memcpy(buffer->data, JSON_EMPTY_PAYLOAD, JSON_EMPTY_PAYLOAD_SIZE);
    buffer->data_size = JSON_EMPTY_PAYLOAD_SIZE;

    return true;
}

void
sentry_batch_buffer_destroy(SentryBatchBuffer *buffer)
{
    if (buffer == NULL) {
        return;
    }

    if (buffer->data != NULL) {
        free(buffer->data);
        buffer->data = NULL;
    }

    buffer->data_capacity = 0;
    buffer->data_size = 0;
    buffer->item_count = 0;
}

bool
sentry_batch_buffer_add_item(SentryBatchBuffer *buffer, const char *data, size_t length)
{
    if (buffer == NULL || data == NULL) {
        return false;
    }

    if (length == 0) {
        return true;
    }

    size_t comma_size = (buffer->item_count > 0) ? 1 : 0;
    size_t required_capacity = buffer->data_size + comma_size + length;
    if (required_capacity > buffer->data_capacity) {
        return false;
    }

    // Remove the closing suffix
    buffer->data_size -= JSON_SUFFIX_SIZE;

    // Add comma separator for subsequent items
    if (buffer->item_count > 0) {
        buffer->data[buffer->data_size] = ',';
        buffer->data_size++;
    }

    // Copy data to the end of the buffer
    memcpy(buffer->data + buffer->data_size, data, length);
    buffer->data_size += length;

    // Append the closing suffix
    memcpy(buffer->data + buffer->data_size, JSON_SUFFIX, JSON_SUFFIX_SIZE);
    buffer->data_size += JSON_SUFFIX_SIZE;

    buffer->item_count++;

    return true;
}

const char *
sentry_batch_buffer_get_data(const SentryBatchBuffer *buffer)
{
    if (buffer == NULL || buffer->data == NULL || buffer->data_size == 0) {
        return NULL;
    }
    return buffer->data;
}

size_t
sentry_batch_buffer_get_data_size(const SentryBatchBuffer *buffer)
{
    if (buffer == NULL) {
        return 0;
    }
    return buffer->data_size;
}

size_t
sentry_batch_buffer_get_data_capacity(const SentryBatchBuffer *buffer)
{
    if (buffer == NULL) {
        return 0;
    }
    return buffer->data_capacity;
}

void
sentry_batch_buffer_clear(SentryBatchBuffer *buffer)
{
    if (buffer == NULL) {
        return;
    }

    // Reset to empty JSON payload
    if (buffer->data != NULL && buffer->data_capacity >= JSON_EMPTY_PAYLOAD_SIZE) {
        memcpy(buffer->data, JSON_EMPTY_PAYLOAD, JSON_EMPTY_PAYLOAD_SIZE);
        buffer->data_size = JSON_EMPTY_PAYLOAD_SIZE;
    } else {
        buffer->data_size = 0;
    }

    buffer->item_count = 0;
}

size_t
sentry_batch_buffer_get_item_count(const SentryBatchBuffer *buffer)
{
    if (buffer == NULL) {
        return 0;
    }
    return buffer->item_count;
}
