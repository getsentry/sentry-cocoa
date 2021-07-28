#import <XCTest/XCTest.h>
#import "SentryCrashSystemCapabilities.h"

#if SentryCrashCRASH_HOST_MAC
#import "SentryCrashIOKit.h"
#endif

@interface SentryCrashIOKit_Tests : XCTestCase
@end

@implementation SentryCrashIOKit_Tests

- (void)testGetMacAddress
{
#if SentryCrashCRASH_HOST_MAC
    unsigned char macAddress[6] = { 0 };
    bool success = sentrycrashiokit_getPrimaryInterfaceMacAddress((char *)macAddress);
    XCTAssertTrue(success, @"");
    unsigned int result = 0;
    for (unsigned i = 0; i < sizeof(macAddress); i++) {
        result |= macAddress[i];
    }
    XCTAssertTrue(result != 0, @"");
#endif
}

@end
