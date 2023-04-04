#import <Foundation/Foundation.h>

/**
 * Given a format string and arguments to format, return an NSString encapsulating the result.
 * Prefer use of this over @c +[NSString @c stringWithFormat:] or @c -[@(someInt) @c stringValue] .
 * @note Only meant for strings where length isn't known at compile time.
 */
static inline NSString *
sentry_format(const char *format, ...)
{
    va_list args;
    va_start(args, format);
    int bufferSize = snprintf(NULL, 0, format, args) + 1;
    char *buffer = (char *)malloc(bufferSize);
    snprintf(buffer, bufferSize, format, args);
    va_end(args);

    NSString *nsString = [NSString stringWithUTF8String:buffer];
    free(buffer);

    return nsString;
}

#define SENTRY_UINT64_TO_STRING(variable) sentry_format("%llu", variable)

static inline NSString *
sentry_formatHexAddress(NSNumber *value)
{
    return sentry_format("0x%016llx", [value unsignedLongLongValue]);
}

static inline NSString *
sentry_formatHexAddressUInt64(uint64_t value)
{
    return sentry_format("0x%016llx", value);
}
