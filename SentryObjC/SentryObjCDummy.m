#import <Foundation/Foundation.h>

// SPM requires at least one compilable source file per target. Importing the
// umbrella here also gets every public header parsed at build time so a
// typo in any of them fails fast.
#import "SentryObjC.h"

NS_ASSUME_NONNULL_BEGIN

@interface SentryObjCDummy : NSObject
@end

@implementation SentryObjCDummy
@end

NS_ASSUME_NONNULL_END
