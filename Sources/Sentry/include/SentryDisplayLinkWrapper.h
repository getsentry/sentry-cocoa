#import "SentryDefines.h"

NS_ASSUME_NONNULL_BEGIN

@interface SentryDisplayLinkWrapper : NSObject

@property (readonly, nonatomic) CFTimeInterval timestamp;

- (void)linkWithTarget:(id)target selector:(SEL)sel;

- (void)invalidate;

@end

NS_ASSUME_NONNULL_END
