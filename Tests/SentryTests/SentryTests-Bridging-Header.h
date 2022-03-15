//
//  Use this file to import your target's public headers that you would like to
//  expose to Swift.
//
#import "NSData+Sentry.h"
#import "NSData+SentryCompression.h"
#import "NSDate+SentryExtras.h"
#import "NSURLProtocolSwizzle.h"
#import "PrivateSentrySDKOnly.h"
#import "SentryANRTracker.h"
#import "SentryANRTrackingIntegration.h"
#import "SentryAppStartMeasurement.h"
#import "SentryAppStartTracker.h"
#import "SentryAppStartTrackingIntegration.h"
#import "SentryAppState.h"
#import "SentryAppStateManager.h"
#import "SentryAttachment.h"
#import "SentryAutoBreadcrumbTrackingIntegration+Test.h"
#import "SentryAutoBreadcrumbTrackingIntegration.h"
#import "SentryAutoSessionTrackingIntegration.h"
#import "SentryBreadcrumbTracker.h"
#import "SentryByteCountFormatter.h"
#import "SentryClassRegistrator.h"
#import "SentryClient+Private.h"
#import "SentryClient+TestInit.h"
#import "SentryConcurrentRateLimitsDictionary.h"
#import "SentryCrashAdapter.h"
#import "SentryCrashBinaryImageProvider.h"
#import "SentryCrashC.h"
#import "SentryCrashDebug.h"
#import "SentryCrashDefaultBinaryImageProvider.h"
#import "SentryCrashDefaultMachineContextWrapper.h"
#import "SentryCrashInstallationReporter.h"
#import "SentryCrashIntegration+TestInit.h"
#import "SentryCrashIntegration.h"
#import "SentryCrashJSONCodecObjC.h"
#import "SentryCrashMachineContext.h"
#import "SentryCrashMonitor.h"
#import "SentryCrashMonitorContext.h"
#import "SentryCrashMonitor_System.h"
#import "SentryCrashReport.h"
#import "SentryCrashReportSink.h"
#import "SentryCrashReportStore.h"
#import "SentryCrashScopeObserver.h"
#import "SentryCrashStackEntryMapper.h"
#import "SentryCrashUUIDConversion.h"
#import "SentryCurrentDate.h"
#import "SentryDateUtil.h"
#import "SentryDebugImageProvider+TestInit.h"
#import "SentryDebugImageProvider.h"
#import "SentryDebugMeta.h"
#import "SentryDefaultCurrentDateProvider.h"
#import "SentryDefaultObjCRuntimeWrapper.h"
#import "SentryDefaultRateLimits.h"
#import "SentryDependencyContainer.h"
#import "SentryDispatchQueueWrapper.h"
#import "SentryDisplayLinkWrapper.h"
#import "SentryDsn.h"
#import "SentryEnvelopeItemType.h"
#import "SentryEnvelopeRateLimit.h"
#import "SentryFileContents.h"
#import "SentryFileIOTrackingIntegration.h"
#import "SentryFileManager+TestProperties.h"
#import "SentryFileManager.h"
#import "SentryFrame.h"
#import "SentryFrameRemover.h"
#import "SentryFramesTracker+TestInit.h"
#import "SentryFramesTracker.h"
#import "SentryFramesTrackingIntegration.h"
#import "SentryHttpDateParser.h"
#import "SentryHttpTransport.h"
#import "SentryHub+Private.h"
#import "SentryHub+TestInit.h"
#import "SentryId.h"
#import "SentryInAppLogic.h"
#import "SentryInitializeForGettingSubclassesNotCalled.h"
#import "SentryInstallation.h"
#import "SentryLevelMapper.h"
#import "SentryLog+TestInit.h"
#import "SentryLog.h"
#import "SentryLogOutput.h"
#import "SentryMechanism.h"
#import "SentryMechanismMeta.h"
#import "SentryMeta.h"
#import "SentryMigrateSessionInit.h"
#import "SentryNSDataTracker.h"
#import "SentryNSError.h"
#import "SentryNSURLRequest.h"
#import "SentryNSURLSessionTaskSearch.h"
#import "SentryNetworkTracker.h"
#import "SentryNetworkTrackingIntegration.h"
#import "SentryNoOpSpan.h"
#import "SentryObjCRuntimeWrapper.h"
#import "SentryOptions+Private.h"
#import "SentryOutOfMemoryLogic.h"
#import "SentryOutOfMemoryTracker.h"
#import "SentryOutOfMemoryTrackingIntegration.h"
#import "SentryPerformanceTracker.h"
#import "SentryPerformanceTrackingIntegration.h"
#import "SentryQueueableRequestManager.h"
#import "SentryRandom.h"
#import "SentryRateLimitCategory.h"
#import "SentryRateLimitCategoryMapper.h"
#import "SentryRateLimitParser.h"
#import "SentryRateLimits.h"
#import "SentryRetryAfterHeaderParser.h"
#import "SentrySDK+Private.h"
#import "SentrySDK+Tests.h"
#import "SentryScope+Private.h"
#import "SentryScopeObserver.h"
#import "SentryScopeSyncC.h"
#import "SentryScreenFrames.h"
#import "SentrySdkInfo.h"
#import "SentrySerialization.h"
#import "SentrySession+Private.h"
#import "SentrySessionTracker.h"
#import "SentrySpan.h"
#import "SentrySpanId.h"
#import "SentryStacktrace.h"
#import "SentryStacktraceBuilder.h"
#import "SentrySubClassFinder.h"
#import "SentrySysctl.h"
#import "SentrySystemEventBreadcrumbs.h"
#import "SentryTestIntegration.h"
#import "SentryTestObjCRuntimeWrapper.h"
#import "SentryThread.h"
#import "SentryThreadInspector.h"
#import "SentryThreadWrapper.h"
#import "SentryTraceState.h"
#import "SentryTracer+Test.h"
#import "SentryTracer.h"
#import "SentryTransaction+Private.h"
#import "SentryTransaction.h"
#import "SentryTransport.h"
#import "SentryTransportFactory.h"
#import "SentryUIViewControllerPerformanceTracker.h"
#import "SentryUIViewControllerSanitizer.h"
#import "SentryUIViewControllerSwizzling+Test.h"
#import "SentryUIViewControllerSwizzling.h"
#import "SentryUserFeedback.h"
#import "TestSentryCrashAdapter.h"
#import "TestSentrySpan.h"
#import "TestUrlSession.h"
#import "UIViewController+Sentry.h"
#import "URLSessionTaskMock.h"
