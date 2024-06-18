#import "SentryLog.h"
#import <Foundation/Foundation.h>

/**
 * Configures a the sentry log output for testing when this class is loaded.
 */
@interface SentryTestLogConfig : NSObject

+ (void)setDefaultTestLogging;

@end

@implementation SentryTestLogConfig

+ (void)load
{
    if (self == [SentryTestLogConfig class]) {
        [SentryTestLogConfig setDefaultTestLogging];
    }
}

+ (void)setDefaultTestLogging
{
    [SentryLog.sharedInstance configure:YES diagnosticLevel:kSentryLevelDebug];
}

@end
