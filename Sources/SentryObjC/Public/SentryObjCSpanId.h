#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentryObjCSpanId : NSObject

@property (nonatomic, readonly, copy) NSString *sentrySpanIdString;
@property (nonatomic, class, readonly, strong) SentryObjCSpanId *empty;

- (instancetype)init;
- (instancetype)initWithUuid:(NSUUID *)uuid;
- (instancetype)initWithValue:(NSString *)value;

@end

NS_ASSUME_NONNULL_END
