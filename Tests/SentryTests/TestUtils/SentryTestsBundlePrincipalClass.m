#import <Foundation/Foundation.h>
#include <stdio.h>
#include <stdlib.h>

/**
 * A dummy principal class for the SentryTests bundle so NSBundle/XCTest doesn't fall back to the
 * first class in the image.
 */
@interface SentryTestsBundlePrincipalClass : NSObject
@end

@implementation SentryTestsBundlePrincipalClass

+ (void)initialize
{
    if (self != [SentryTestsBundlePrincipalClass class]) {
        return;
    }

    fprintf(stderr, "*** SentryTestsBundlePrincipalClass +initialize called\n");
    abort();
}

@end
