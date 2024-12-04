#import "SentrySdkPackage+Equality.h"

@implementation SentrySdkPackage (Equality)

- (BOOL)isEqual:(id _Nullable)object
{
    if (object == self)
        return YES;
    if ([self class] != [object class])
        return NO;

    SentrySdkPackage *other = (SentrySdkPackage *)object;

    if (![self.name isEqualToString:other.name]) {
        return NO;
    }

    if (![self.version isEqualToString:other.version]) {
        return NO;
    }

    return YES;
}

- (NSUInteger)hash
{
    NSUInteger hash = 17;

    hash = hash * 23 + [self.name hash];
    hash = hash * 23 + [self.version hash];

    return hash;
}

@end
