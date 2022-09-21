#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

NSString *
getCPUArchitecture();


NSString *
getOSName();

NSString *
getOSVersion();

NSString *
getDeviceModel()
;

NSString *
getOSBuildNumber()
;

BOOL
isSimulatorBuild()
;

NS_ASSUME_NONNULL_END
