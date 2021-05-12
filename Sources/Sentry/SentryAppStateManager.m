#import "SentryCrashSysCtl.h"
#import "SentrySystemInfo.h"
#import <Foundation/Foundation.h>
#import <SentryAppState.h>
#import <SentryAppStateManager.h>
#import <SentryCrashAdapter.h>
#import <SentryCurrentDateProvider.h>
#import <SentryFileManager.h>
#import <SentryOptions.h>

#if SENTRY_HAS_UIKIT
#    import <UIKit/UIKit.h>
#endif

@interface
SentryAppStateManager ()

@property (nonatomic, strong) SentryOptions *options;
@property (nonatomic, strong) SentryCrashAdapter *crashAdapter;
@property (nonatomic, strong) SentryFileManager *fileManager;
@property (nonatomic, strong) id<SentryCurrentDateProvider> currentDate;
@property (nonatomic, strong) SentrySystemInfo *systemInfo;

@end

@implementation SentryAppStateManager

- (instancetype)initWithOptions:(SentryOptions *)options
                   crashAdapter:(SentryCrashAdapter *)crashAdatper
                    fileManager:(SentryFileManager *)fileManager
            currentDateProvider:(id<SentryCurrentDateProvider>)currentDateProvider
                     systemInfo:(SentrySystemInfo *)systemInfo
{
    if (self = [super init]) {
        self.options = options;
        self.crashAdapter = crashAdatper;
        self.fileManager = fileManager;
        self.currentDate = currentDateProvider;
        self.systemInfo = systemInfo;
    }
    return self;
}

#if SENTRY_HAS_UIKIT

- (SentryAppState *)buildCurrentAppState
{
    // Is the current process being traced or not? If it is a debugger is attached.
    bool isDebugging = self.crashAdapter.isBeingTraced;

    NSDate *systemBootTimeStamp = self.systemInfo.systemBootTimestamp;
    // Round down to seconds as the precision of the serialization of the date is only milliseconds.
    // With this we avoid getting different dates before and after serialization.
    NSTimeInterval interval = round(systemBootTimeStamp.timeIntervalSince1970);
    systemBootTimeStamp = [[NSDate alloc] initWithTimeIntervalSince1970:interval];

    return [[SentryAppState alloc] initWithReleaseName:self.options.releaseName
                                             osVersion:UIDevice.currentDevice.systemVersion
                                           isDebugging:isDebugging
                                   systemBootTimestamp:systemBootTimeStamp];
}

- (SentryAppState *)loadCurrentAppState
{
    return [self.fileManager readAppState];
}

- (void)storeCurrentAppState
{
    [self.fileManager storeAppState:[self buildCurrentAppState]];
}

#endif

@end
