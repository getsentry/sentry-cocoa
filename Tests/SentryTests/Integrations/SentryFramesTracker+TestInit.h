#import "SentryFramesTracker.h"

NS_ASSUME_NONNULL_BEGIN

@interface SentryFramesTracker (TestInit)

- (instancetype)initWithDisplayLinkWrapper:(SentryDisplayLinkWrapper *)displayLinkWrapper;

@end

NS_ASSUME_NONNULL_END
