#import "SentrySdkInfo.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentrySdkInfo ()

@end

@implementation SentrySdkInfo

- (instancetype)initWithName:(NSString *)name
                  andVersion:(NSString *)version
                 andPackages:(NSSet<SentrySdkPackage *> *)packages
{
    if (self = [super init]) {
        _name = name ?: @"";
        _version = version ?: @"";
        _packages = packages ?: [NSSet set];
    }

    return self;
}

- (instancetype)initWithName:(NSString *)name andVersion:(NSString *)version
{
    return [self initWithName:name andVersion:version andPackages:[NSSet set]];
}

- (instancetype)initWithDict:(NSDictionary *)dict
{
    return [self initWithDictInternal:dict orDefaults:nil];
}

- (instancetype)initWithDict:(NSDictionary *)dict orDefaults:(SentrySdkInfo *)info;
{
    return [self initWithDictInternal:dict orDefaults:info];
}

- (instancetype)initWithDictInternal:(NSDictionary *)dict orDefaults:(SentrySdkInfo *_Nullable)info;
{
    NSString *name = @"";
    NSString *version = @"";
    NSSet *packages = [NSSet set];

    if (nil != dict[@"sdk"] && [dict[@"sdk"] isKindOfClass:[NSDictionary class]]) {
        NSDictionary<NSString *, id> *sdkInfoDict = dict[@"sdk"];
        if ([sdkInfoDict[@"name"] isKindOfClass:[NSString class]]) {
            name = sdkInfoDict[@"name"];
        } else if (info && info.name) {
            name = info.name;
        }

        if ([sdkInfoDict[@"version"] isKindOfClass:[NSString class]]) {
            version = sdkInfoDict[@"version"];
        } else if (info && info.version) {
            version = info.version;
        }

        if ([sdkInfoDict[@"packages"] isKindOfClass:[NSArray class]]) {
            NSMutableSet *newPackages = [NSMutableSet set];
            for (id maybePackageDict in sdkInfoDict[@"packages"]) {
                if ([maybePackageDict isKindOfClass:[NSDictionary class]]) {
                    SentrySdkPackage *package =
                        [[SentrySdkPackage alloc] initWithDict:maybePackageDict];
                    if (package != nil) {
                        [newPackages addObject:package];
                    }
                }
            }
            packages = newPackages;
        } else if (info && info.packages) {
            packages = info.packages;
        }
    }

    return [self initWithName:name andVersion:version andPackages:packages];
}

- (NSDictionary<NSString *, id> *)serialize
{
    NSMutableArray *serializedPackages = [NSMutableArray array];
    for (SentrySdkPackage *package in self.packages) {
        [serializedPackages addObject:[package serialize]];
    }

    return @{
        @"sdk" : @ {
            @"name" : self.name,
            @"version" : self.version,
            @"packages" : serializedPackages,
        },
    };
}

@end

NS_ASSUME_NONNULL_END
