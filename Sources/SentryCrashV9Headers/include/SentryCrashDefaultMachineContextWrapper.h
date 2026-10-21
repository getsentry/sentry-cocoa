#import "SentryDefines.h"

#if !SDK_V10
#    import "SentryCrashMachineContextWrapper.h"
#    import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentryCrashDefaultMachineContextWrapper : NSObject <SentryCrashMachineContextWrapper>

@end

NS_ASSUME_NONNULL_END
#endif // !SDK_V10
