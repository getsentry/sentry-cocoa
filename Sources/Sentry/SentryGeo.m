#import "SentryGeo.h"

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@implementation SentryGeo

- (instancetype)init
{
    return [super init];
}

- (id)copyWithZone:(nullable NSZone *)zone
{
    SentryGeo *copy = [[SentryGeo allocWithZone:zone] init];

    @synchronized(self) {
        if (copy != nil) {
            copy.city = self.city;
            copy.countryCode = self.countryCode;
            copy.region = self.region;
        }
    }

    return copy;
}

- (NSDictionary<NSString *, id> *)serialize
{
    NSMutableDictionary *serializedData = [[NSMutableDictionary alloc] init];

    @synchronized(self) {
        [serializedData setValue:self.city forKey:@"city"];
        [serializedData setValue:self.countryCode forKey:@"country_code"];
        [serializedData setValue:self.region forKey:@"region"];
    }

    return serializedData;
}

- (BOOL)isEqual:(id _Nullable)other
{
    @synchronized(self) {
        if (other == self) {
            return YES;
        }
        if (!other || ![[other class] isEqual:[self class]]) {
            return NO;
        }

        return [self isEqualToGeo:other];
    }
}

- (BOOL)isEqualToGeo:(SentryGeo *)geo
{
    @synchronized(self) {
        // We need to get some local copies of the properties, because they could be modified during
        // the if statements

        if (self == geo) {
            return YES;
        }
        if (geo == nil) {
            return NO;
        }

        NSString *otherCity = geo.city;
        if (self.city != otherCity && ![self.city isEqualToString:otherCity]) {
            return NO;
        }

        NSString *otherCountryCode = geo.countryCode;
        if (self.countryCode != otherCountryCode
            && ![self.countryCode isEqualToString:otherCountryCode]) {
            return NO;
        }

        NSString *otherRegion = geo.region;
        if (self.region != otherRegion && ![self.region isEqualToString:otherRegion]) {
            return NO;
        }

        return YES;
    }
}

- (NSUInteger)hash
{
    @synchronized(self) {
        NSUInteger hash = 17;

        hash = hash * 23 + [self.city hash];
        hash = hash * 23 + [self.countryCode hash];
        hash = hash * 23 + [self.region hash];

        return hash;
    }
}

@end

NS_ASSUME_NONNULL_END
