//
//  sentry_batch_buffer.c
//
//  Buffer wrapper for managing memory buffers.
//

#include "SentryBatchBufferC.h"
#include <stdlib.h>
#include <string.h>

bool
sentry_batch_buffer_init(SentryBatchBufferC *buffer, size_t data_capacity, size_t max_items)
{
    if (buffer == NULL) {
        return false;
    }

    buffer->data = NULL;
    buffer->data_capacity = 0;
    buffer->data_size = 0;
    buffer->item_offsets = NULL;
    buffer->item_sizes = NULL;
    buffer->items_capacity = 0;
    buffer->item_count = 0;

    if (data_capacity == 0 || max_items == 0) {
        return true;
    }

    buffer->data = (char *)malloc(data_capacity);
    if (buffer->data == NULL) {
        return false;
    }
    buffer->data_capacity = data_capacity;

    buffer->item_offsets = (size_t *)malloc(max_items * sizeof(size_t));
    if (buffer->item_offsets == NULL) {
        free(buffer->data);
        buffer->data = NULL;
        return false;
    }

    buffer->item_sizes = (size_t *)malloc(max_items * sizeof(size_t));
    if (buffer->item_sizes == NULL) {
        free(buffer->item_offsets);
        free(buffer->data);
        buffer->item_offsets = NULL;
        buffer->data = NULL;
        return false;
    }

    buffer->items_capacity = max_items;

    return true;
}

void
sentry_batch_buffer_destroy(SentryBatchBufferC *buffer)
{
    if (buffer == NULL) {
        return;
    }

    if (buffer->data != NULL) {
        free(buffer->data);
        buffer->data = NULL;
    }

    if (buffer->item_offsets != NULL) {
        free(buffer->item_offsets);
        buffer->item_offsets = NULL;
    }

    if (buffer->item_sizes != NULL) {
        free(buffer->item_sizes);
        buffer->item_sizes = NULL;
    }

    buffer->data_capacity = 0;
    buffer->data_size = 0;
    buffer->items_capacity = 0;
    buffer->item_count = 0;
}

bool
sentry_batch_buffer_add_item(SentryBatchBufferC *buffer, const char *data, size_t length)
{
    if (buffer == NULL || data == NULL) {
        return false;
    }

    if (length == 0) {
        return true;
    }

    if (buffer->item_count >= buffer->items_capacity) {
        return false;
    }

    if (buffer->data_size + length > buffer->data_capacity) {
        return false;
    }

    buffer->item_offsets[buffer->item_count] = buffer->data_size;
    buffer->item_sizes[buffer->item_count] = length;

    memcpy(buffer->data + buffer->data_size, data, length);
    buffer->data_size += length;

    buffer->item_count++;
    return true;
}

const char *
sentry_batch_buffer_get_item(const SentryBatchBufferC *buffer, size_t index, size_t *size_out)
{
    if (buffer == NULL) {
        return NULL;
    }

    if (index >= buffer->item_count) {
        return NULL;
    }

    if (size_out != NULL) {
        *size_out = buffer->item_sizes[index];
    }

    return buffer->data + buffer->item_offsets[index];
}

const char *
sentry_batch_buffer_get_data(const SentryBatchBufferC *buffer)
{
    if (buffer == NULL || buffer->data == NULL || buffer->data_size == 0) {
        return NULL;
    }
    return buffer->data;
}

size_t
sentry_batch_buffer_get_data_size(const SentryBatchBufferC *buffer)
{
    if (buffer == NULL) {
        return 0;
    }
    return buffer->data_size;
}

size_t
sentry_batch_buffer_get_data_capacity(const SentryBatchBufferC *buffer)
{
    if (buffer == NULL) {
        return 0;
    }
    return buffer->data_capacity;
}

void
sentry_batch_buffer_clear(SentryBatchBufferC *buffer)
{
    if (buffer == NULL) {
        return;
    }

    buffer->data_size = 0;
    buffer->item_count = 0;
}

size_t
sentry_batch_buffer_get_item_count(const SentryBatchBufferC *buffer)
{
    if (buffer == NULL) {
        return 0;
    }
    return buffer->item_count;
}
