#import <Foundation/Foundation.h>

// 2 for the 0x prefix, plus 16 for the hex value, plus 1 for the null terminator
#define SENTRY_HEX_ADDRESS_LENGTH 19

static inline NSString *
sentry_snprintfHexAddress(uint64_t value)
{
    char buffer[SENTRY_HEX_ADDRESS_LENGTH];
    snprintf(buffer, SENTRY_HEX_ADDRESS_LENGTH, "0x%016llx", value);
    NSString *nsString = [NSString stringWithCString:buffer encoding:NSASCIIStringEncoding];
    return nsString;
}

static inline NSString *
sentry_stringForUInt64(uint64_t value)
{
    int bufferSize = snprintf(NULL, 0, "%llu", value) + 1;
    char *buffer = (char *)malloc(bufferSize);
    snprintf(buffer, bufferSize, "%llu", value);
    NSString *nsString = [NSString stringWithCString:buffer encoding:NSASCIIStringEncoding];
    free(buffer);
    return nsString;
}

static inline NSString *
sentry_formatHexAddress(NSNumber *value)
{
    return sentry_snprintfHexAddress([value unsignedLongLongValue]);
}

static inline NSString *
sentry_formatHexAddressUInt64(uint64_t value)
{
    return sentry_snprintfHexAddress(value);
}
