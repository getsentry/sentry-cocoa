#import "SentryDependencies.h"
#import "SentryCrashAdapter.h"
#import "SentryDefaultCurrentDateProvider.h"
#import "SentryDispatchQueueWrapper.h"
#import "SentryFileManager.h"
#import <Foundation/Foundation.h>

@implementation SentryDependencies

static id<SentryCurrentDateProvider> currentDateProvider;

+ (id<SentryCurrentDateProvider>)currentDateProvider
{
    if (currentDateProvider == nil) {
        currentDateProvider = [[SentryDefaultCurrentDateProvider alloc] init];
    }
    return currentDateProvider;
}

static SentryCrashAdapter *crashAdapter;

+ (SentryCrashAdapter *)crashAdapter
{
    if (crashAdapter == nil) {
        crashAdapter = [[SentryCrashAdapter alloc] init];
    }

    return crashAdapter;
}

static SentryDispatchQueueWrapper *dispatchQueue;

+ (SentryDispatchQueueWrapper *)dispatchQueue
{
    if (dispatchQueue == nil) {
        dispatchQueue = [[SentryDispatchQueueWrapper alloc] init];
    }

    return dispatchQueue;
}

@end
