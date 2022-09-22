#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

NSString *getCPUArchitecture(void);

NSString *getOSName(void);

NSString *getOSVersion(void);

NSString *getDeviceModel(void);

NSString *getOSBuildNumber(void);

BOOL isSimulatorBuild(void);

NS_ASSUME_NONNULL_END
