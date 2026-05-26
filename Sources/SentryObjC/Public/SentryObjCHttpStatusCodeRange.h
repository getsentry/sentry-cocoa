#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentryObjCHttpStatusCodeRange : NSObject

@property (nonatomic, readonly) NSInteger min;
@property (nonatomic, readonly) NSInteger max;

- (instancetype)initWithMin:(NSInteger)min max:(NSInteger)max;
- (instancetype)initWithStatusCode:(NSInteger)statusCode;

@end

NS_ASSUME_NONNULL_END
