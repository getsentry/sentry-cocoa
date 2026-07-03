#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

#ifdef __cplusplus
extern "C" {
#endif

void CrashE2EInstallFakeManagedRuntimeSignalHandler(const char *markerPath);
NSString *_Nullable CrashE2ELoadDynamicBinaryImage(const char *path, int slot);
void CrashE2ETriggerDynamicBinaryImageCrash(void);
void CrashE2ETriggerCPPException(void);
void CrashE2ETriggerUnitySentryCxaThrow(void);
void CrashE2ETriggerObjCObjectException(void);

#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_END
