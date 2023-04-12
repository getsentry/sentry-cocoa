#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^SentryDelegateSpyCallback)(void);

@interface SentryURLSessionDelegateSpy : NSObject <NSURLSessionDelegate>
@property (nonatomic, copy) SentryDelegateSpyCallback delegateCallback;
@end

NS_ASSUME_NONNULL_END
