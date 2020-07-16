#import "SentrySdkInfo.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@implementation SentrySdkInfo

- (instancetype)initWithSdkName:(NSString *)sdkName andVersionString:(NSString *)versionString
{
    if (self = [super init]) {
        _sdkName = sdkName;

        NSArray<NSString *> *versionComponents = [versionString componentsSeparatedByString:@"."];

        NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
        numberFormatter.numberStyle = NSNumberFormatterDecimalStyle;

        if (versionComponents.count > 0) {
            NSString *major = versionComponents[0];
            _versionMajor = [numberFormatter numberFromString:major];
        }

        if (versionComponents.count > 1) {
            NSString *minor = versionComponents[1];
            _versionMinor = [numberFormatter numberFromString:minor];
        }

        if (versionComponents.count > 2) {
            NSString *patchLevel = versionComponents[2];

            NSCharacterSet *nonNumericCharacters =
                [[NSCharacterSet characterSetWithCharactersInString:@"0123456789"] invertedSet];

            NSRange firstNonNumericIndex =
                [patchLevel rangeOfCharacterFromSet:nonNumericCharacters];

            if (firstNonNumericIndex.location != NSNotFound) {
                patchLevel = [patchLevel substringToIndex:firstNonNumericIndex.location];
            }

            _versionPatchLevel = [numberFormatter numberFromString:patchLevel];
        }
    }

    return self;
}

- (instancetype _Nullable)initWithDict:(NSDictionary *)dict
{
    if (nil == dict) {
        return nil;
    }

    NSDictionary<NSString *, id> *sdkInfoDict = dict[@"sdk_info"];
    if (nil == sdkInfoDict) {
        return nil;
    }

    NSString *_Nullable sdkName = sdkInfoDict[@"sdk_name"];
    NSNumber *_Nullable versionMajor = sdkInfoDict[@"version_major"];
    NSNumber *_Nullable versionMinor = sdkInfoDict[@"version_minor"];
    NSNumber *_Nullable versionPatchLevel = sdkInfoDict[@"version_patchlevel"];

    NSString *versionString =
        [NSString stringWithFormat:@"%@.%@.%@", versionMajor, versionMinor, versionPatchLevel];

    SentrySdkInfo *sdkInfo = [[SentrySdkInfo alloc] initWithSdkName:sdkName
                                                   andVersionString:versionString];

    return sdkInfo;
}

- (NSDictionary<NSString *, id> *)serialize
{
    return @{
        @"sdk_info" : @ {
            @"sdk_name" : self.sdkName,
            @"version_major" : self.versionMajor,
            @"version_minor" : self.versionMinor,
            @"version_patchlevel" : self.versionPatchLevel
        }
    };
}

@end

NS_ASSUME_NONNULL_END
