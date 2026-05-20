#import <Foundation/Foundation.h>

/// Origin of a transaction name.
typedef NS_ENUM(NSInteger, SentryCompatTransactionNameSource) {
    SentryCompatTransactionNameSourceCustom = 0,
    SentryCompatTransactionNameSourceUrl = 1,
    SentryCompatTransactionNameSourceRoute = 2,
    SentryCompatTransactionNameSourceView = 3,
    SentryCompatTransactionNameSourceComponent = 4,
    SentryCompatTransactionNameSourceSourceTask = 5,
};
