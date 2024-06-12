#import <Foundation/Foundation.h>
#import <Sentry/SentryDefines.h>

#if SENTRY_UIKIT_AVAILABLE
@class SentryReplayOptions;

@protocol SentryViewScreenshotProvider;
@protocol SentryReplayBreadcrumbConverter;

@interface SentrySessionReplayIntegration : NSObject

- (void)startWithOptions:(SentryReplayOptions *)replayOptions
      screenshotProvider:(id<SentryViewScreenshotProvider>)screenshotProvider
     breadcrumbConverter:(id<SentryReplayBreadcrumbConverter>)breadcrumbConverter
             fullSession:(BOOL)shouldReplayFullSession;

@end

#endif
