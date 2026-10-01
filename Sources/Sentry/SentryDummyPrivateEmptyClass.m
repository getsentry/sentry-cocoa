// Check selection during C compilation as well as Swift's private-module imports.
#import "include/SentryCrashBackendSelection.h"
#import <Foundation/Foundation.h>

// This class is required because SPM doesn't support header only targets

NS_ASSUME_NONNULL_BEGIN

@interface SentryPrivateDummyEmptyClass : NSObject

@end

NS_ASSUME_NONNULL_END
