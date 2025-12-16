//
//  main.c
//
//  Sample usage of sentry_batch_buffer
//

#include "sentry_batch_buffer.h"
#include <stdio.h>
#include <string.h>

#define ONE_MB (1024 * 1024)

int
main(void)
{
    SentryBatchBuffer buffer;

    // Initialize buffer with 1MB capacity
    if (!sentry_batch_buffer_init(&buffer, ONE_MB)) {
        fprintf(stderr, "Failed to initialize buffer\n");
        return 1;
    }

    // Fill buffer with JSON items (commas are added automatically)
    // Each item is a simple JSON object like {"id":N}
    char item[64];
    size_t remaining = ONE_MB;

    while (remaining > 0) {
        // Create a JSON item
        size_t current_count = sentry_batch_buffer_get_item_count(&buffer);
        int written = snprintf(item, sizeof(item), "{\"id\":%zu}", current_count);
        if (written < 0 || (size_t)written >= sizeof(item)) {
            break;
        }

        size_t item_len = (size_t)written;
        // Account for comma that will be added automatically (except for first item)
        if (current_count > 0) {
            item_len += 1; // Add space for comma
        }

        if (item_len > remaining) {
            break;
        }

        if (!sentry_batch_buffer_add_item(&buffer, item, (size_t)written)) {
            break;
        }

        remaining -= item_len;
    }

    // Read the data back
    const char *data = sentry_batch_buffer_get_data(&buffer);
    size_t data_size = sentry_batch_buffer_get_data_size(&buffer);
    size_t item_count = sentry_batch_buffer_get_item_count(&buffer);
    if (data != NULL && data_size > 0) {
        printf("Buffer contains %zu bytes with %zu items\n", data_size, item_count);
        printf("First 100 bytes: \"%.100s\"\n", data);
    }

    // Cleanup
    sentry_batch_buffer_destroy(&buffer);
    return 0;
}
