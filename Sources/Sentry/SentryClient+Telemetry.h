#import "SentryClient+Private.h"

@class SentryCurrentScopeStorage;
@class SentryDispatchQueueWrapper;

@protocol SentryLogScopeApplier;
@protocol SentryObjCTelemetryProcessor;

NS_ASSUME_NONNULL_BEGIN

@interface SentryClientInternal ()

@property (nonatomic, strong) id<SentryLogScopeApplier> logScopeApplier;
@property (nonatomic, strong) id<SentryObjCTelemetryProcessor> telemetryProcessor;
@property (nonatomic, strong) SentryDispatchQueueWrapper *dispatchQueueWrapper;
@property (nonatomic, strong) SentryCurrentScopeStorage *currentScopeStorage;

@end

NS_ASSUME_NONNULL_END
