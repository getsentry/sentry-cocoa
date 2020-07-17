#import "SentrySdkInterface.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@implementation SentrySdkInterface

- (instancetype)initWithName:(NSString *)name andVersion:(NSString *)version
{
    if (self = [super init]) {

        if ([name length] == 0) {
            _name = @"";
        } else {
            _name = name;
        }

        if ([version length] == 0) {
            _version = @"";
        } else {
            _version = version;
        }
    }

    return self;
}

- (instancetype)initWithDict:(NSDictionary *)dict
{
    if (self = [super init]) {

        if (nil == dict) {
            _name = @"";
            _version = @"";
            return self;
        }

        if (nil != dict[@"sdk"] && [dict[@"sdk"] isKindOfClass:[NSDictionary class]]) {
            NSDictionary<NSString *, id> *sdkInterfaceDict = dict[@"sdk"];
            if ([sdkInterfaceDict[@"name"] isKindOfClass:[NSString class]]) {
                _name = sdkInterfaceDict[@"name"];
            }

            if ([sdkInterfaceDict[@"version"] isKindOfClass:[NSString class]]) {
                _version = sdkInterfaceDict[@"version"];
            }
        } else {
            _name = @"";
            _version = @"";
        }
    }

    return self;
}

- (NSDictionary<NSString *, id> *)serialize
{
    return @{ @"sdk" : @ { @"name" : self.name, @"version" : self.version } };
}

@end

NS_ASSUME_NONNULL_END
