#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentryObjCMessage : NSObject

@property (nonatomic, readonly, copy) NSString *formatted;
@property (nonatomic, copy, nullable) NSString *message;
@property (nonatomic, strong, nullable) NSArray<NSString *> *params;

- (instancetype)initWithFormatted:(NSString *)formatted;

@end

NS_ASSUME_NONNULL_END
