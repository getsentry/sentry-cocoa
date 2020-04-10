#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol SentryRequestManager <NSObject>

@property(nonatomic, readonly, getter = isReady) BOOL ready;

- (instancetype)initWithSession:(NSURLSession *)session;

- (void)addRequest:(NSURLRequest *)request completionHandler:(_Nullable SentryRequestOperationFinished)completionHandler;

- (void)cancelAllOperations;

@end

NS_ASSUME_NONNULL_END
