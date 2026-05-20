#import <Foundation/Foundation.h>

/// Crash status of the previous program execution.
typedef NS_ENUM(NSInteger, SentryCompatLastRunStatus) {
    SentryCompatLastRunStatusUnknown = 0,
    SentryCompatLastRunStatusDidNotCrash = 1,
    SentryCompatLastRunStatusDidCrash = 2,
};
