#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, SentryObjCLogLevel) {
    SentryObjCLogLevelTrace = 0,
    SentryObjCLogLevelDebug,
    SentryObjCLogLevelInfo,
    SentryObjCLogLevelWarn,
    SentryObjCLogLevelError,
    SentryObjCLogLevelFatal
};
