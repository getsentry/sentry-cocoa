#import "SentryInternalDefines.h"
#import "SentrySDKSettings+Equality.h"

@implementation SentrySDKSettings (Equality)

- (BOOL)isEqual:(id _Nullable)object
{
    if (object == self)
        return YES;
    if ([self class] != [object class])
        return NO;

    SentrySDKSettings *_Nonnull otherSDKSettings
        = SENTRY_UNWRAP_NULLABLE(SentrySDKSettings, object);

    if (!self.autoInferIP == otherSDKSettings.autoInferIP) {
        return NO;
    }

    return YES;
}

- (NSUInteger)hash
{
    NSUInteger hash = 19;

    hash = hash * 29 + [@(self.autoInferIP) integerValue];

    return hash;
}

@end
