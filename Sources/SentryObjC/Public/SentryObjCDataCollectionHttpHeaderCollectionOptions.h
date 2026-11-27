#import <Foundation/Foundation.h>

@class SentryObjCDataCollectionKeyValueCollectionBehavior;

NS_ASSUME_NONNULL_BEGIN

/// Controls HTTP header collection independently for request and response directions.
@interface SentryObjCDataCollectionHttpHeaderCollectionOptions : NSObject

/// Controls collection of request header values. Defaults to denyList.
@property (nonatomic, strong) SentryObjCDataCollectionKeyValueCollectionBehavior *request;

/// Controls collection of response header values. Defaults to denyList.
@property (nonatomic, strong) SentryObjCDataCollectionKeyValueCollectionBehavior *response;

- (instancetype)init;

@end

NS_ASSUME_NONNULL_END
