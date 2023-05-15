#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentrySingleExecution : NSObject

@property (nonatomic, readonly) BOOL isRunning;

/**
 * Execute the block and avoid any other parallel call
 * to @c standaloneExecution while the first call is in execution.
 *
 * @return Whether the block was executed or not.
 */
- (BOOL)standaloneExecution:(void (^)(void))block;

@end

NS_ASSUME_NONNULL_END
