#import "SentryCrashDynamicLinker.h"
#import "SentryCrashStackCursor.h"
#import "SentryDefines.h"
#import <Foundation/Foundation.h>

@class SentryFrame;

NS_ASSUME_NONNULL_BEGIN

@interface SentryCrashStackEntryMapper : NSObject

/** Maps the stackEntry of a SentryCrashStackCursor to SentryFrame.
 *
 * @param stackCursor An with SentryCrash initialized stackCursor. You can use for example
 * sentrycrashsc_initSelfThread.
 */
+ (SentryFrame *)mapStackEntryWithCursor:(SentryCrashStackCursor)stackCursor;

@end

NS_ASSUME_NONNULL_END
