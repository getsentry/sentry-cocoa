#import <Foundation/Foundation.h>

#if TARGET_OS_OSX

@interface SentryUncaughtNSExceptions : NSObject

+ (void)capture:(NSException *)exception;

@end

#endif // TARGET_OS_OSX
