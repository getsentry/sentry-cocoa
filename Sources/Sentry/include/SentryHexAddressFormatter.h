#import <Foundation/Foundation.h>
#import "NSString+SentryUnsignedLongLongValue.h"
#import "NSNumber+SentryUnsignedLongLongValue.h"

static inline NSString *
sentry_formatHexAddress(NSNumber *value)
{
    return [NSString stringWithFormat:@"0x%016llx", [value sentry_unsignedLongLongValue]];
}
