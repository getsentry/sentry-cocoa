/**
 * SentrySwiftUI needs a class from Sentry that is not public.
 * The easiest way do expose this class is by copying it interface.
 * We could just add the original header file to SwntrySwiftUI project,
 * but the original file has reference to other header that we don't need here.
 */

#import <Foundation/Foundation.h>

#import <Sentry/Sentry-Swift.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, SentryTransactionNameSource);

@class SentrySpanId;
@protocol SentrySpan;

typedef NS_ENUM(NSUInteger, SentrySpanStatus);

@interface SentryPerformanceTracker : NSObject

@property (nonatomic, class, readonly) SentryPerformanceTracker *shared;

- (SentrySpanId *)startSpanWithName:(NSString *)name
                         nameSource:(SentryTransactionNameSource)source
                          operation:(NSString *)operation
                             origin:(NSString *)origin;

- (void)activateSpan:(SentrySpanId *)spanId duringBlock:(void (^)(void))block;

- (void)measureSpanWithDescription:(NSString *)description
                        nameSource:(SentryTransactionNameSource)source
                         operation:(NSString *)operation
                            origin:(NSString *)origin
                           inBlock:(void (^)(void))block;

- (void)measureSpanWithDescription:(NSString *)description
                        nameSource:(SentryTransactionNameSource)source
                         operation:(NSString *)operation
                            origin:(NSString *)origin
                      parentSpanId:(SentrySpanId *)parentSpanId
                           inBlock:(void (^)(void))block;

- (nullable SentrySpanId *)activeSpanId;

- (void)finishSpan:(SentrySpanId *)spanId;

- (void)finishSpan:(SentrySpanId *)spanId withStatus:(SentrySpanStatus)status;

- (BOOL)isSpanAlive:(SentrySpanId *)spanId;

- (nullable id<SentrySpan>)getSpan:(SentrySpanId *)spanId;

- (BOOL)pushActiveSpan:(SentrySpanId *)spanId;

- (void)popActiveSpan;

@end

//@interface SentrySpanOperation : NSObject
//@property (nonatomic, class, readonly, copy) NSString * _Nonnull appLifecycle;
//+ (NSString * _Nonnull)appLifecycle;
//@property (nonatomic, class, readonly, copy) NSString * _Nonnull coredataFetchOperation;
//+ (NSString * _Nonnull)coredataFetchOperation;
//@property (nonatomic, class, readonly, copy) NSString * _Nonnull coredataSaveOperation;
//+ (NSString * _Nonnull)coredataSaveOperation;
//@property (nonatomic, class, readonly, copy) NSString * _Nonnull fileRead;
//+ (NSString * _Nonnull)fileRead;
//@property (nonatomic, class, readonly, copy) NSString * _Nonnull fileWrite;
//+ (NSString * _Nonnull)fileWrite;
//@property (nonatomic, class, readonly, copy) NSString * _Nonnull networkRequestOperation;
//+ (NSString * _Nonnull)networkRequestOperation;
//@property (nonatomic, class, readonly, copy) NSString * _Nonnull uiAction;
//+ (NSString * _Nonnull)uiAction;
//@property (nonatomic, class, readonly, copy) NSString * _Nonnull uiActionClick;
//+ (NSString * _Nonnull)uiActionClick;
//@property (nonatomic, class, readonly, copy) NSString * _Nonnull uiLoad;
//+ (NSString * _Nonnull)uiLoad;
//@property (nonatomic, class, readonly, copy) NSString * _Nonnull uiLoadInitialDisplay;
//+ (NSString * _Nonnull)uiLoadInitialDisplay;
//@property (nonatomic, class, readonly, copy) NSString * _Nonnull uiLoadFullDisplay;
//+ (NSString * _Nonnull)uiLoadFullDisplay;
// - (nonnull instancetype)init __attribute__((objc_designated_initializer));
//@end

NS_ASSUME_NONNULL_END
