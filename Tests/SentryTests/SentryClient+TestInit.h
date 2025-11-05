#import "SentryTransport.h"

@protocol SentryCurrentDateProvider;
@protocol SentryRandomProtocol;

@class SentryCrashWrapper;
@class SentryDispatchQueueWrapper;
@class SentryDefaultThreadInspector;
@class SentryTransportAdapter;
@class SentryDebugImageProvider;

NS_ASSUME_NONNULL_BEGIN

@interface SentryClientInternal ()

- (instancetype)initWithOptions:(NSObject *)options
               transportAdapter:(SentryTransportAdapter *)transportAdapter
                    fileManager:(SentryFileManager *)fileManager
                threadInspector:(SentryDefaultThreadInspector *)threadInspector
             debugImageProvider:(SentryDebugImageProvider *)debugImageProvider
                         random:(id<SentryRandomProtocol>)random
                         locale:(NSLocale *)locale
                       timezone:(NSTimeZone *)timezone;

@end

NS_ASSUME_NONNULL_END
