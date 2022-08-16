#import <XCTest/XCTest.h>

NS_ASSUME_NONNULL_BEGIN

typedef void(^SentryTestMethodLogic)(XCTestCase *testCase);

@interface XCTestCase(SentryDynamicMethods)

/**
 * Helper method to dynamically add a test method to this @c XCTestCase.
 * @note This must be called from @c +[XCTestCase @c initialize] , which is not possible to override
 * from Swift @c XCTestCase subclasses, so it can only be used in Objectve-C source files.
 * @seealso See https://www.gaige.net/dynamic-xctests.html
 * @param selectorName The name for the test case method to be generated.
 * @param testLogic A closure encapsulating the logic to run in the generated test case.
 */
+ (BOOL)sentry_addInstanceMethodWithSelectorName:(NSString *)selectorName
                                       testLogic:(SentryTestMethodLogic)testLogic;

@end

NS_ASSUME_NONNULL_END
