#import <Foundation/Foundation.h>

static BOOL SentryInitializerCalled = NO;

@interface SentryInitializeNotCalled : NSObject

+ (BOOL)wasInitializerCalled;

+ (void)resetWasInitializerCalled;

@end
