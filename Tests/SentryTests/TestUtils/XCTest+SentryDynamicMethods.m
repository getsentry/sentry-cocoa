#import "XCTest+SentryDynamicMethods.h"
#import <objc/runtime.h>

@implementation
XCTestCase (SentryDynamicMethods)

+ (BOOL)sentry_addInstanceMethodWithSelectorName:(NSString *)selectorName
                                       testLogic:(SentryTestMethodLogic)testLogic
{
    NSParameterAssert(selectorName);
    NSParameterAssert(testLogic);

    // See
    // http://stackoverflow.com/questions/6357663/casting-a-block-to-a-void-for-dynamic-class-method-resolution
    id testLogicBlockPointer = (__bridge id)(__bridge void *)(testLogic);
    IMP testLogicDynamicImplementation = imp_implementationWithBlock(testLogicBlockPointer);
    SEL testCaseMethodSelector = NSSelectorFromString(selectorName);
    return class_addMethod(self, testCaseMethodSelector, testLogicDynamicImplementation, "v@:");
}

@end
