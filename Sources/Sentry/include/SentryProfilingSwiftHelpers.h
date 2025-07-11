#import "SentryProfilingConditionals.h"
#import <Foundation/Foundation.h>

@class SentryId;
@class SentryProfileOptions;
@class SentrySpanId;
@class SentryClient;
@class SentryDispatchQueueWrapper;
@class SentryTransactionContext;

NS_ASSUME_NONNULL_BEGIN

// The functions in this file exist to bridge ObjectiveC++ to Swift. When building with Swift
// Package Manager you can’t import Swift into ObjectiveC++ so instead that code calls plain C
// functions in this file which then uses Swift in their implementation.

#ifdef __cplusplus
extern "C" {
#endif

BOOL isContinuousProfilingEnabled(SentryClient *client);
BOOL isContinuousProfilingV2Enabled(SentryClient *client);
BOOL isProfilingCorrelatedToTraces(SentryClient *client);
SentryProfileOptions *getProfiling(SentryClient *client);
NSString *stringFromSentryID(SentryId *sentryID);
NSDate *getDate(void);
uint64_t getSystemTime(void);
SentryId *getSentryId(void);
SentryProfileOptions *getSentryProfileOptions(void);
BOOL isTraceLifecycle(SentryProfileOptions *options);
float sessionSampleRate(SentryProfileOptions *options);
BOOL profileAppStarts(SentryProfileOptions *options);
BOOL isTrace(int lifecycle);
BOOL isManual(int lifecycle);
SentrySpanId *getParentSpanID(SentryTransactionContext *context);
SentryId *getTraceID(SentryTransactionContext *context);
BOOL isNotSampled(SentryTransactionContext *context);
void dispatchAsync(SentryDispatchQueueWrapper *wrapper, dispatch_block_t block);
void dispatchAsyncOnMain(SentryDispatchQueueWrapper *wrapper, dispatch_block_t block);
void addObserver(id observer, SEL selector, NSNotificationName name, _Nullable id object);
void removeObserver(id observer);
void postNotification(NSNotification *notification);
id addObserverForName(NSNotificationName name, dispatch_block_t block);

#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_END
