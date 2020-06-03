#import "SentryCrashDynamicLinker.h"
#import "SentryCrashStackCursor.h"
#import "SentryDefines.h"
#import <Foundation/Foundation.h>

@class SentryFrame;

NS_ASSUME_NONNULL_BEGIN

@interface SentryCrashStackEntryMapper : NSObject

+ (SentryFrame *)mapStackEntryWithCursor:(SentryCrashStackCursor)stackCursor;

@end

NS_ASSUME_NONNULL_END
