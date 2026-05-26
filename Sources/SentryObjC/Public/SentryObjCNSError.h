#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentryObjCNSError : NSObject

@property (nonatomic, copy) NSString *domain;
@property (nonatomic, assign) NSInteger code;

- (instancetype)initWithDomain:(NSString *)domain code:(NSInteger)code;

@end

NS_ASSUME_NONNULL_END
