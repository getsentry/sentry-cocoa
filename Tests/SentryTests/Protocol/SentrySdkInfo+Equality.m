#import "SentrySdkInfo+Equality.h"
#import <Sentry/Sentry-Swift.h>

@implementation SentrySdkInfo (Equality)

- (BOOL)isEqual:(id _Nullable)object
{
    if (object == self)
        return YES;
    if ([self class] != [object class])
        return NO;

    SentrySdkInfo *otherSdkInfo = (SentrySdkInfo *)object;

    if (![self.name isEqualToString:otherSdkInfo.name]) {
        return NO;
    }

    if (![self.version isEqualToString:otherSdkInfo.version]) {
        return NO;
    }

    if (![[NSSet setWithArray:self.integrations]
            isEqualToSet:[NSSet setWithArray:otherSdkInfo.integrations]]) {
        return NO;
    }

    if (![[NSSet setWithArray:self.features]
            isEqualToSet:[NSSet setWithArray:otherSdkInfo.features]]) {
        return NO;
    }

    if (![[NSSet setWithArray:self.packages]
            isEqualToSet:[NSSet setWithArray:otherSdkInfo.packages]]) {
        return NO;
    }

    if (![self.settings isEqual:otherSdkInfo.settings]) {
        return NO;
    }

    return YES;
}

- (NSUInteger)hash
{
    NSUInteger hash = 17;

    hash = hash * 23 + [self.name hash];
    hash = hash * 23 + [self.version hash];
    hash = hash * 23 + [self.integrations hash];
    hash = hash * 23 + [self.features hash];
    hash = hash * 23 + [self.packages hash];
    hash = hash * 23 + [self.settings hash];

    return hash;
}

@end
