#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol Random

/**
 * Returns a random number uniformly distributed over the interval [0.0 , 1.0].
 */
- (double)nextNumber;

@end

@interface Random : NSObject <Random>

- (double)nextNumber;

@end

NS_ASSUME_NONNULL_END
