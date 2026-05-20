#import <Foundation/Foundation.h>

/// Crash status of the previous program execution.
typedef NS_ENUM(NSInteger, SOCSentryLastRunStatus) {
    SOCSentryLastRunStatusUnknown = 0,
    SOCSentryLastRunStatusDidNotCrash = 1,
    SOCSentryLastRunStatusDidCrash = 2,
};
