#import <Foundation/Foundation.h>

@class SentryANRStoppedResultInternal;

typedef NS_ENUM(NSInteger, SentryANRTypeInternal) {
    kSentryANRTypeFatalFullyBlocking,
    kSentryANRTypeFatalNonFullyBlocking,
    kSentryANRTypeFullyBlocking,
    kSentryANRTypeNonFullyBlocking,
    kSentryANRTypeUnknown
};

NS_ASSUME_NONNULL_BEGIN

@protocol SentryANRTrackerInternalDelegate <NSObject>

- (void)anrDetected:(SentryANRTypeInternal)type;

- (void)anrStopped:(nullable SentryANRStoppedResultInternal *)result;

@end

NS_ASSUME_NONNULL_END
