#import <Foundation/Foundation.h>

@class SentryObjCEvent;

NS_ASSUME_NONNULL_BEGIN

@interface SentryObjCEnvelopeItem : NSObject

@property (nonatomic, readonly, strong, nullable) NSData *data;
@property (nonatomic, readonly, copy) NSString *type;

- (instancetype)initWithType:(NSString *)type
                        data:(nullable NSData *)data
                 contentType:(NSString *)contentType
                   itemCount:(NSNumber *)itemCount;
- (instancetype)initWithType:(NSString *)type
                        data:(nullable NSData *)data
                 addPlatform:(BOOL)addPlatform;
- (instancetype)initWithEvent:(SentryObjCEvent *)event;

@end

NS_ASSUME_NONNULL_END
