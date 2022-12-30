#import "SentryBaseIntegration.h"
#import "SentryEvent.h"
#import "SentryIntegrationProtocol.h"
#import "SentrySwift.h"
#import <Foundation/Foundation.h>

#if SENTRY_HAS_METRIC_KIT

NS_ASSUME_NONNULL_BEGIN

static NSString *const SentryMetricKitDiskWriteExceptionType = @"MXDiskWriteException";
static NSString *const SentryMetricKitDiskWriteExceptionMechanism = @"mx_disk_write_exception";

static NSString *const SentryMetricKitCpuExceptionType = @"MXCPUException";
static NSString *const SentryMetricKitCpuExceptionMechanism = @"mx_cpu_exception";

API_AVAILABLE(ios(14.0), macos(12.0))
API_UNAVAILABLE(tvos, watchos)
@interface SentryMetricKitIntegration
    : SentryBaseIntegration <SentryIntegrationProtocol, SentryMXManagerDelegate>

@end

@interface
SentryEvent (MetricKit)

@property (nonatomic, readonly) BOOL isMetricKitEvent;

@end

NS_ASSUME_NONNULL_END

#endif
