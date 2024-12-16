#import "SentryExtraPackages.h"
#import "SentryMeta.h"

static NSSet<NSDictionary<NSString *, NSString *> *> *extraPackages;

NS_ASSUME_NONNULL_BEGIN

@implementation SentryExtraPackages

+ (void)addPackageName:(NSString *)name version:(NSString *)version
{
    if (name == nil || version == nil) {
        return;
    }

    @synchronized(extraPackages) {
        NSDictionary<NSString *, NSString *> *newPackage =
            @{ @"name" : name, @"version" : version };
        if (extraPackages == nil) {
            extraPackages = [[NSSet alloc] initWithObjects:newPackage, nil];
        } else {
            extraPackages = [extraPackages setByAddingObject:newPackage];
        }
    }
}

+ (NSMutableSet<NSDictionary<NSString *, NSString *> *> *)getPackages
{
    @synchronized(extraPackages) {
        if (extraPackages == nil) {
            return [[NSMutableSet alloc] init];
        } else {
            return [extraPackages mutableCopy];
        }
    }
}

#if TEST || TESTCI
+ (void)clear
{
    extraPackages = [[NSSet alloc] init];
}
#endif

@end

NS_ASSUME_NONNULL_END
