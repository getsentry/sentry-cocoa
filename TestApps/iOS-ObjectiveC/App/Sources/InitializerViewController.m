#import "InitializerViewController.h"
#import <Foundation/Foundation.h>

@implementation InitializerViewController

+ (void)initialize
{
    NSAssert([NSThread isMainThread], @"Initializer must only be called from the main thread.");
}

@end
