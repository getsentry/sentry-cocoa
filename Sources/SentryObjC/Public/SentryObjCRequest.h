#import <Foundation/Foundation.h>

#import "SentryObjCSerializable.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * HTTP request information for an event.
 *
 * @see SentryEvent
 */
@interface SentryRequest : NSObject <SentrySerializable>

@property (nonatomic, copy, nullable) NSNumber *bodySize;
@property (nonatomic, copy, nullable) NSString *cookies;
@property (nonatomic, strong, nullable) NSDictionary<NSString *, NSString *> *headers;
@property (nonatomic, copy, nullable) NSString *fragment;
@property (nonatomic, copy, nullable) NSString *method;
@property (nonatomic, copy, nullable) NSString *queryString;
@property (nonatomic, copy, nullable) NSString *url;

- (instancetype)init;

@end

NS_ASSUME_NONNULL_END
