#import "SentryCrashMonitor_CPPException.h"
#import <XCTest/XCTest.h>

#include <iostream>
#include <stdexcept>

@interface SentryCrashMonitor_CppException_Tests : XCTestCase

@end

@implementation SentryCrashMonitor_CppException_Tests

bool terminateCalled = false;

void
testTerminationHandler()
{
    terminateCalled = true;
}

- (void)setUp
{
    [super setUp];
    terminateCalled = false;
}

- (void)testCallTerminationHandler_NotEnabled
{

    std::set_terminate(&testTerminationHandler);

    sentrycrashcm_cppexception_callOriginalTerminationHandler();

    XCTAssertFalse(terminateCalled);
}

- (void)testCallTerminationHandler_Enabled
{

    std::set_terminate(&testTerminationHandler);

    SentryCrashMonitorAPI *api = sentrycrashcm_cppexception_getAPI();
    api->setEnabled(true);

    sentrycrashcm_cppexception_callOriginalTerminationHandler();

    XCTAssertTrue(terminateCalled);

    api->setEnabled(false);
}

@end
