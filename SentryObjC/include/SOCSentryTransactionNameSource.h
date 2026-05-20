#import <Foundation/Foundation.h>

/// Origin of a transaction name.
typedef NS_ENUM(NSInteger, SOCSentryTransactionNameSource) {
    SOCSentryTransactionNameSourceCustom = 0,
    SOCSentryTransactionNameSourceUrl = 1,
    SOCSentryTransactionNameSourceRoute = 2,
    SOCSentryTransactionNameSourceView = 3,
    SOCSentryTransactionNameSourceComponent = 4,
    SOCSentryTransactionNameSourceSourceTask = 5,
};
