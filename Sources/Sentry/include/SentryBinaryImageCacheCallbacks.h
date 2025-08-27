#import <Foundation/Foundation.h>

#if __has_include(<Sentry/SentryCrashDynamicLinker.h>)
#    import <Sentry/SentryCrashDynamicLinker.h>
#else
#    import "SentryCrashDynamicLinker.h"
#endif

#ifdef __cplusplus
extern "C" {
#endif

void binaryImageWasAdded(const SentryCrashBinaryImage *_Nullable image);

void binaryImageWasRemoved(const SentryCrashBinaryImage *_Nullable image);

#ifdef __cplusplus
}
#endif
