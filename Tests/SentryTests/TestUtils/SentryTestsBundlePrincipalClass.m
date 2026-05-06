#import <Foundation/Foundation.h>

/**
 * A dummy principal class for the SentryTests bundle so NSBundle/XCTest doesn't fall back to the
 * first class in the image.
 */
@interface SentryTestsBundlePrincipalClass : NSObject
@end

@implementation SentryTestsBundlePrincipalClass
@end
