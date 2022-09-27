#import <Foundation/Foundation.h>

@interface SentryDependencyContainer : NSObject

NS_ASSUME_NONNULL_BEGIN

@property (nonatomic, class, readonly) SentryDependencyContainer *sharedInstance;

- (void)registerProtocol:(Protocol *)proto withImplementation:(id (^)(void))callback;

- (nullable id)implementationForProtocol:(Protocol *)proto;

@end

NS_ASSUME_NONNULL_END
