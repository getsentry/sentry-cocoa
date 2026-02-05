#import "SentryTransport.h"

@protocol SentryCurrentDateProvider;
@protocol SentryRandomProtocol;
@protocol SentryEventContextEnricher;

@class SentryCrashWrapper;
@class SentryDispatchQueueWrapper;
@class SentryDefaultThreadInspector;
@class SentryTransportAdapter;
@class SentryDebugImageProvider;

NS_ASSUME_NONNULL_BEGIN

@interface SentryClientInternal ()

- (instancetype)initWithOptions:(NSObject *)options
                   dateProvider:(id<SentryCurrentDateProvider>)dateProvider
               transportAdapter:(SentryTransportAdapter *)transportAdapter
                    fileManager:(SentryFileManager *)fileManager
                threadInspector:(SentryDefaultThreadInspector *)threadInspector
             debugImageProvider:(SentryDebugImageProvider *)debugImageProvider
                         random:(id<SentryRandomProtocol>)random
                         locale:(NSLocale *)locale
                       timezone:(NSTimeZone *)timezone
           eventContextEnricher:(id<SentryEventContextEnricher>)eventContextEnricher
             notificationCenter:(id<SentryNSNotificationCenterWrapper>)notificationCenter;

@end

NS_ASSUME_NONNULL_END
