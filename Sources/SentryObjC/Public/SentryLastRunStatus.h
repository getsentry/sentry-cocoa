#import <Foundation/Foundation.h>

/**
 * Represents the crash status of the last program execution.
 *
 * Use @c +[SentrySDK lastRunStatus] to check if the previous app execution
 * terminated with a crash.
 */
typedef NS_ENUM(NSInteger, SentryLastRunStatus) {
    SentryLastRunStatusUnknown = 0,
    SentryLastRunStatusDidNotCrash = 1,
    SentryLastRunStatusDidCrash = 2
};
