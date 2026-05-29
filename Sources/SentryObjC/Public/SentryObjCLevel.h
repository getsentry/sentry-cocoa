#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, SentryObjCLevel) {
    SentryObjCLevelNone = 0,
    SentryObjCLevelDebug,
    SentryObjCLevelInfo,
    SentryObjCLevelWarning,
    SentryObjCLevelError,
    SentryObjCLevelFatal
};
