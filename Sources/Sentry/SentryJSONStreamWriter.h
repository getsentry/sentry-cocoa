#ifndef SentryJSONStreamWriter_h
#define SentryJSONStreamWriter_h

#include <stdbool.h>
#include <stddef.h>

#define SENTRY_JSON_STREAM_MAX_CONTAINERS 192

/**
 * This writer is not generally async-signal-safe. The callback executes caller-owned code, and
 * sentryJSONStreamWriter_addDouble uses snprintf. Keeping storage bounded and allocation-free in
 * this translation unit does not make callers such as UIKit view-hierarchy capture signal-safe.
 */
typedef bool (*SentryJSONStreamWriteFunc)(const char *data, size_t length, void *userData);

typedef struct {
    SentryJSONStreamWriteFunc write;
    void *userData;
    int containerLevel;
    bool isObject[SENTRY_JSON_STREAM_MAX_CONTAINERS];
    bool isFirstElement[SENTRY_JSON_STREAM_MAX_CONTAINERS];
    bool failed;
} SentryJSONStreamWriter;

void sentryJSONStreamWriter_init(
    SentryJSONStreamWriter *writer, SentryJSONStreamWriteFunc write, void *userData);

bool sentryJSONStreamWriter_beginObject(SentryJSONStreamWriter *writer, const char *name);
bool sentryJSONStreamWriter_beginArray(SentryJSONStreamWriter *writer, const char *name);
bool sentryJSONStreamWriter_endContainer(SentryJSONStreamWriter *writer);
bool sentryJSONStreamWriter_addString(
    SentryJSONStreamWriter *writer, const char *name, const char *value);
/** Not async-signal-safe: preserves legacy %lg formatting through snprintf. */
bool sentryJSONStreamWriter_addDouble(
    SentryJSONStreamWriter *writer, const char *name, double value);
bool sentryJSONStreamWriter_addBool(SentryJSONStreamWriter *writer, const char *name, bool value);
bool sentryJSONStreamWriter_finish(SentryJSONStreamWriter *writer);

#endif /* SentryJSONStreamWriter_h */
