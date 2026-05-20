#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Information about an HTTP request attached to an event.
@interface SentryCompatRequest : NSObject

- (instancetype)init;

@property (nonatomic, strong, nullable) NSNumber *bodySize;
@property (nonatomic, copy, nullable) NSString *cookies;
@property (nonatomic, copy, nullable) NSDictionary<NSString *, NSString *> *headers;
@property (nonatomic, copy, nullable) NSString *fragment;
@property (nonatomic, copy, nullable) NSString *method;
@property (nonatomic, copy, nullable) NSString *queryString;
@property (nonatomic, copy, nullable) NSString *url;

@end

NS_ASSUME_NONNULL_END
