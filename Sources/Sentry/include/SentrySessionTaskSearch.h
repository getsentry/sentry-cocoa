#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentrySessionTaskSearch : NSObject

+ (NSArray<Class> *)urlSessionTaskClassesToTrack;

@end

NS_ASSUME_NONNULL_END
