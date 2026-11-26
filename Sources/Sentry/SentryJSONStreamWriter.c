#include "SentryJSONStreamWriter.h"

#include <math.h>
#include <stdio.h>

static bool
writeJSON(SentryJSONStreamWriter *const writer, const char *const data, const size_t length)
{
    // The writer cannot make this indirect call async-signal-safe. Its safety depends entirely on
    // the caller-provided output implementation.
    if (writer->failed || writer->write == NULL || !writer->write(data, length, writer->userData)) {
        writer->failed = true;
        return false;
    }
    return true;
}

static bool
writeJSONString(SentryJSONStreamWriter *const writer, const char *const value)
{
    if (value == NULL || !writeJSON(writer, "\"", 1)) {
        writer->failed = true;
        return false;
    }

    const unsigned char *position = (const unsigned char *)value;
    const unsigned char *spanStart = position;

    while (*position != '\0') {
        const char *escape = NULL;

        switch (*position) {
        case '\"':
            escape = "\\\"";
            break;
        case '\\':
            escape = "\\\\";
            break;
        case '\b':
            escape = "\\b";
            break;
        case '\f':
            escape = "\\f";
            break;
        case '\n':
            escape = "\\n";
            break;
        case '\r':
            escape = "\\r";
            break;
        case '\t':
            escape = "\\t";
            break;
        default:
            if (*position < 0x20) {
                writer->failed = true;
                return false;
            }
            break;
        }

        if (escape != NULL) {
            const size_t spanLength = (size_t)(position - spanStart);
            if ((spanLength > 0 && !writeJSON(writer, (const char *)spanStart, spanLength))
                || !writeJSON(writer, escape, 2)) {
                return false;
            }
            spanStart = position + 1;
        }
        position++;
    }

    const size_t spanLength = (size_t)(position - spanStart);
    return (spanLength == 0 || writeJSON(writer, (const char *)spanStart, spanLength))
        && writeJSON(writer, "\"", 1);
}

static bool
beginElement(SentryJSONStreamWriter *const writer, const char *const name)
{
    if (writer->failed) {
        return false;
    }
    if (writer->containerLevel < 0) {
        return true;
    }

    const int level = writer->containerLevel;
    if (!writer->isFirstElement[level] && !writeJSON(writer, ",", 1)) {
        return false;
    }
    writer->isFirstElement[level] = false;

    if (writer->isObject[level]) {
        if (name == NULL || !writeJSONString(writer, name) || !writeJSON(writer, ":", 1)) {
            writer->failed = true;
            return false;
        }
    }
    return true;
}

static bool
beginContainer(SentryJSONStreamWriter *const writer, const char *const name, const bool isObject)
{
    if (writer->containerLevel + 1 >= SENTRY_JSON_STREAM_MAX_CONTAINERS
        || !beginElement(writer, name)) {
        writer->failed = true;
        return false;
    }

    writer->containerLevel++;
    writer->isObject[writer->containerLevel] = isObject;
    writer->isFirstElement[writer->containerLevel] = true;
    return writeJSON(writer, isObject ? "{" : "[", 1);
}

void
sentryJSONStreamWriter_init(SentryJSONStreamWriter *const writer,
    const SentryJSONStreamWriteFunc write, void *const userData)
{
    *writer = (SentryJSONStreamWriter) {
        .write = write,
        .userData = userData,
        .containerLevel = -1,
    };
}

bool
sentryJSONStreamWriter_beginObject(SentryJSONStreamWriter *const writer, const char *const name)
{
    return beginContainer(writer, name, true);
}

bool
sentryJSONStreamWriter_beginArray(SentryJSONStreamWriter *const writer, const char *const name)
{
    return beginContainer(writer, name, false);
}

bool
sentryJSONStreamWriter_endContainer(SentryJSONStreamWriter *const writer)
{
    if (writer->failed || writer->containerLevel < 0) {
        writer->failed = true;
        return false;
    }

    const bool isObject = writer->isObject[writer->containerLevel];
    writer->containerLevel--;
    return writeJSON(writer, isObject ? "}" : "]", 1);
}

bool
sentryJSONStreamWriter_addString(
    SentryJSONStreamWriter *const writer, const char *const name, const char *const value)
{
    return beginElement(writer, name) && writeJSONString(writer, value);
}

bool
sentryJSONStreamWriter_addDouble(
    SentryJSONStreamWriter *const writer, const char *const name, const double value)
{
    if (!beginElement(writer, name)) {
        return false;
    }
    if (isnan(value)) {
        return writeJSON(writer, "null", 4);
    }
    if (isinf(value)) {
        return value > 0 ? writeJSON(writer, "1e999", 5) : writeJSON(writer, "-1e999", 6);
    }

    // snprintf is intentionally retained for exact legacy %lg parity. It is not
    // async-signal-safe; V9 view-hierarchy attachment capture may reach this code from its
    // on-crash callback, so this writer does not make that existing path signal-safe.
    char buffer[64];
    const int length = snprintf(buffer, sizeof(buffer), "%lg", value);
    if (length < 0 || length >= (int)sizeof(buffer)) {
        writer->failed = true;
        return false;
    }
    return writeJSON(writer, buffer, (size_t)length);
}

bool
sentryJSONStreamWriter_addBool(
    SentryJSONStreamWriter *const writer, const char *const name, const bool value)
{
    return beginElement(writer, name) && writeJSON(writer, value ? "true" : "false", value ? 4 : 5);
}

bool
sentryJSONStreamWriter_finish(SentryJSONStreamWriter *const writer)
{
    if (writer->failed || writer->containerLevel != -1) {
        writer->failed = true;
        return false;
    }
    return true;
}
