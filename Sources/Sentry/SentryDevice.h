#import <Foundation/Foundation.h>
/**
 * @seealso TargetConditionals.h has explanations and diagrams that show the relationships between
 * different @c TARGET_OS_... and @c TARGET_CPU_... macros.
 */

NS_ASSUME_NONNULL_BEGIN

/**
 * @return The CPU architecture name, such as @c armv7, @c arm64 or @c x86_64.
 */
NSString *getCPUArchitecture(void);

/**
 * @return The name of the operating system, such as @c iOS or @c macOS.
 */
NSString *getOSName(void);

/**
 * @return The OS version with up to three period-delimited numbers, like @c 14 , @c 14.0 or
 * @c 14.0.1 .
 */
NSString *getOSVersion(void);

/**
 * @return The Apple hardware descriptor, such as @c iPhone14,4 or @c MacBookPro10,8 .
 * @note If running on a simulator, this will be the model of the mac running the simulator.
 * @seealso See @c getSimulatorDeviceModel() for retrieving the model of the simulator.
 */
NSString *getDeviceModel(void);

#if TARGET_OS_SIMULATOR
/**
 * @return The Apple hardware descriptor of the simulated device, such as @c iPhone14,4 or @c
 * MacBookPro10,8 .
 */
NSString *_Nullable getSimulatorDeviceModel(void);
#endif // TARGET_OS_SIMULATOR

/**
 * @return A string describing the OS version's specific build, with alphanumeric characters, like
 * @c 21G115 .
 */
NSString *getOSBuildNumber(void);

/**
 * @return @c YES if built and running in a simulator on a mac device, @c NO if running on a device.
 */
BOOL isSimulatorBuild(void);

NS_ASSUME_NONNULL_END
