#import "SentryFrameInAppLogic.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface
SentryFrameInAppLogic ()

@property (nonatomic, copy, readonly) NSArray<NSString *> *inAppIncludes;
@property (nonatomic, copy, readonly) NSArray<NSString *> *inAppExcludes;

@end

@implementation SentryFrameInAppLogic

- (instancetype)initWithInAppIncludes:(NSArray<NSString *> *)inAppIncludes
                        inAppExcludes:(NSArray<NSString *> *)inAppExcludes
{
    if (self = [super init]) {
        _inAppIncludes = inAppIncludes;
        _inAppExcludes = inAppExcludes;
    }

    return self;
}

- (BOOL)isInApp:(NSString *)imageName
{
    for (NSString *inAppInclude in self.inAppIncludes) {
        if ([imageName hasSuffix:inAppInclude])
            return YES;
    }

    for (NSString *inAppExlude in self.inAppExcludes) {
        if ([imageName hasSuffix:inAppExlude])
            return NO;
    }

    return NO;
}

@end

NS_ASSUME_NONNULL_END
