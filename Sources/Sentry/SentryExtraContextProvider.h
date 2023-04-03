#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Provider of dynamic context data that we need to read at the time of an exception.
 */
@interface SentryExtraContextProvider : NSObject

+ (instancetype)sharedInstance;

- (_Nonnull instancetype)init;

- (NSDictionary *)getExtraContext;

@end

NS_ASSUME_NONNULL_END
