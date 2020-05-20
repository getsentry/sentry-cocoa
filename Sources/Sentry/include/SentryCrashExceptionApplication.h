// TargetConditionals.h is needed so that `#if TARGET_OS_OSX` is working
// fine. If we remove this the SDK breaks for MacOS.
#import "TargetConditionals.h"
#if TARGET_OS_OSX
#    import <AppKit/NSApplication.h>
@interface SentryCrashExceptionApplication : NSApplication
#else
#    import <Foundation/Foundation.h>
@interface SentryCrashExceptionApplication : NSObject
#endif

@end
