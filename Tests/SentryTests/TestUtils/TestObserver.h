

#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Report failing tests to Sentry.
 */
@interface TestObserver : NSObject <XCTestObservation>

@end

NS_ASSUME_NONNULL_END
