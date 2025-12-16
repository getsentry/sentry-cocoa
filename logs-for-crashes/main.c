//
//  main.c
//
//  Sample usage of sentry_buffer
//

#include "sentry_buffer.h"
#include <stdio.h>
#include <string.h>

int
main(void)
{
    SentryBuffer buffer;

    // Initialize buffer with 64 bytes capacity
    if (!sentry_buffer_init(&buffer, 64)) {
        fprintf(stderr, "Failed to initialize buffer\n");
        return 1;
    }

    // Write some data
    const char *text = "Hello, World!";
    if (sentry_buffer_write(&buffer, text, strlen(text))) {
        printf("Successfully wrote: %s\n", text);
    }

    // Read the data back
    const char *data = sentry_buffer_get_data(&buffer);
    size_t length = sentry_buffer_get_length(&buffer);
    if (data != NULL && length > 0) {
        printf("Buffer contains %zu bytes: \"%.*s\"\n", length, (int)length, data);
    }

    // Cleanup
    sentry_buffer_destroy(&buffer);
    return 0;
}
