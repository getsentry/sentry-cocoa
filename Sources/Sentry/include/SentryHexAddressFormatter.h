#import <Foundation/Foundation.h>

static inline NSString *
sentry_formatHexAddress(NSNumber *value)
{
    return [NSString stringWithFormat:@"0x%016llx", [value unsignedLongLongValue]];
}

static inline NSString *
sentry_formatHexAddressPointer(uint64_t value)
{
    return [NSString stringWithFormat:@"0x%016llx", value];
}
