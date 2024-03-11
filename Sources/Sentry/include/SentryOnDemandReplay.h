#import "SentryDefines.h"
#import "SentrySwift.h"
#import <Foundation/Foundation.h>
#if SENTRY_HAS_UIKIT
#    import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentryOnDemandReplay : NSObject

@property (nonatomic) NSInteger bitRate;

@property (nonatomic) NSInteger frameRate;

@property (nonatomic) NSUInteger cacheMaxSize;

@property (nonatomic) CGSize videoSize;

- (instancetype)initWithOutputPath:(NSString *)outputPath;

- (void)addFrame:(UIImage *)image;

- (void)createVideoOf:(NSTimeInterval)duration
                 from:(NSDate *)beginning
        outputFileURL:(NSURL *)outputFileURL
           completion:(void (^)(SentryVideoInfo *, NSError *error))completion;

/**
 * Remove cached frames until given date.
 */
- (void)releaseFramesUntil:(NSDate *)date;

@end

NS_ASSUME_NONNULL_END
#endif // SENTRY_HAS_UIKIT
