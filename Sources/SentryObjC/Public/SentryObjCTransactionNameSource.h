#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, SentryObjCTransactionNameSource) {
    SentryObjCTransactionNameSourceCustom = 0,
    SentryObjCTransactionNameSourceUrl,
    SentryObjCTransactionNameSourceRoute,
    SentryObjCTransactionNameSourceView,
    SentryObjCTransactionNameSourceComponent,
    SentryObjCTransactionNameSourceTask
};
