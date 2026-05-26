#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentryObjCId : NSObject

@property (nonatomic, readonly, copy) NSString *sentryIdString;
@property (nonatomic, class, readonly, strong) SentryObjCId *empty;

- (instancetype)init;
- (instancetype)initWithUuid:(NSUUID *)uuid;
- (instancetype)initWithUUIDString:(NSString *)uuidString;

@end

NS_ASSUME_NONNULL_END
