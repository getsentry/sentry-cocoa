#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, SentryObjCLastRunStatus) {
    SentryObjCLastRunStatusUnknown = 0,
    SentryObjCLastRunStatusDidNotCrash,
    SentryObjCLastRunStatusDidCrash
};
