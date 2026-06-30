#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Configuration options for experimental app hang detection.
@interface SentryObjCAppHangsOptions : NSObject

/// Enables the V3 app hang detection mechanism based on run loop observers.
@property (nonatomic) BOOL enableV3;

/// Duration before classifying as an app hang and reporting an event.
@property (nonatomic) NSTimeInterval threshold;

/// Initializes with default values.
- (instancetype)init;

@end

NS_ASSUME_NONNULL_END
