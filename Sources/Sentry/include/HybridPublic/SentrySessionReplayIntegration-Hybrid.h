@class SentrySessionReplayIntegration;
@class SentryReplayOptions;

@interface
SentrySessionReplayIntegration ()

- (void)startWithOptions:(SentryReplayOptions *)replayOptions
      screenshotProvider:(id<SentryViewScreenshotProvider>)screenshotProvider
     breadcrumbConverter:(id<SentryReplayBreadcrumbConverter>)breadcrumbConverter
             fullSession:(BOOL)shouldReplayFullSession;

@end
