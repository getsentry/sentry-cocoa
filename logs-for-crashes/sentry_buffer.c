//
//  sentry_buffer.c
//
//  Buffer wrapper for managing memory buffers.
//

#include "sentry_buffer.h"
#include <stdlib.h>
#include <string.h>

bool
sentry_buffer_init(SentryBuffer *buffer, size_t capacity)
{
    if (buffer == NULL) {
        return false;
    }

    buffer->data = NULL;
    buffer->capacity = 0;
    buffer->length = 0;

    if (capacity == 0) {
        return true;
    }

    buffer->data = (char *)malloc(capacity);
    if (buffer->data == NULL) {
        return false;
    }

    buffer->capacity = capacity;
    return true;
}

void
sentry_buffer_destroy(SentryBuffer *buffer)
{
    if (buffer == NULL) {
        return;
    }

    if (buffer->data != NULL) {
        free(buffer->data);
        buffer->data = NULL;
    }

    buffer->capacity = 0;
    buffer->length = 0;
}

bool
sentry_buffer_write(SentryBuffer *buffer, const char *data, size_t length)
{
    if (buffer == NULL || data == NULL) {
        return false;
    }

    if (length == 0) {
        return true;
    }

    // Check if there's enough space in the buffer
    size_t required_capacity = buffer->length + length;
    if (required_capacity > buffer->capacity) {
        return false;
    }

    // Copy data to the end of the buffer
    memcpy(buffer->data + buffer->length, data, length);
    buffer->length += length;

    return true;
}

const char *
sentry_buffer_get_data(const SentryBuffer *buffer)
{
    if (buffer == NULL || buffer->data == NULL || buffer->length == 0) {
        return NULL;
    }
    return buffer->data;
}

size_t
sentry_buffer_get_length(const SentryBuffer *buffer)
{
    if (buffer == NULL) {
        return 0;
    }
    return buffer->length;
}

size_t
sentry_buffer_get_capacity(const SentryBuffer *buffer)
{
    if (buffer == NULL) {
        return 0;
    }
    return buffer->capacity;
}

void
sentry_buffer_clear(SentryBuffer *buffer)
{
    if (buffer == NULL) {
        return;
    }

    buffer->length = 0;
}
