#import "SentryReplaySettings.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface
SentryReplaySettings (Private)

/**
 * Defines the quality of the session replay.
 * Higher bit rates better quality, but also bigger files to transfer.
 * @note The default value is @c 20000;
 */
@property (nonatomic) NSInteger replayBitRate;

- (instancetype)initWithDictionary:(NSDictionary *)dictionary;

@end

NS_ASSUME_NONNULL_END
