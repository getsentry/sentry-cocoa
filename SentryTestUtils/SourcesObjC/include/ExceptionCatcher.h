#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class NSException;

@interface ExceptionCatcher : NSObject

+ (NSException *_Nullable)tryBlock:(void (^)(void))tryBlock;

@end

NS_ASSUME_NONNULL_END
