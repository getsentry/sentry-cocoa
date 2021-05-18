#import "NSString+SentryUnsignedLongLongValue.h"

@implementation NSString (SentryUnsignedLongLongValue)

- (unsigned long long)sentry_unsignedLongLongValue
{
    return strtoull([self UTF8String], NULL, 0);
}

@end
