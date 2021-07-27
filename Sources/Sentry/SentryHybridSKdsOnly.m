#import "PrivateSentrySDKOnly.h"
#import "SentryDebugImageProvider.h"
#import "SentrySDK+Private.h"
#import "SentrySerialization.h"
#import <Foundation/Foundation.h>

@interface
PrivateSentrySDKOnly ()

@property (nonatomic, strong) SentryDebugImageProvider *debugImageProvider;

@end

@implementation PrivateSentrySDKOnly

static SentryOnAppStartMeasurementAvailable _onAppStartMeasurmentAvailable;

- (instancetype)init
{
    if (self = [super init]) {
        _debugImageProvider = [[SentryDebugImageProvider alloc] init];
    }
    return self;
}

+ (void)storeEnvelope:(SentryEnvelope *)envelope
{
    [SentrySDK storeEnvelope:envelope];
}

+ (void)captureEnvelope:(SentryEnvelope *)envelope
{
    [SentrySDK captureEnvelope:envelope];
}

+ (nullable SentryEnvelope *)envelopeWithData:(NSData *)data
{
    return [SentrySerialization envelopeWithData:data];
}

- (NSArray<SentryDebugMeta *> *)getDebugImages
{
    return [self.debugImageProvider getDebugImages];
}

+ (nullable SentryAppStartMeasurement *)getAppStartMeasurement
{
    return [SentrySDK getAppStartMeasurement];
}

+ (SentryOnAppStartMeasurementAvailable)onAppStartMeasurementAvailable
{
    return _onAppStartMeasurmentAvailable;
}

+ (void)setOnAppStartMeasurementAvailable:
    (SentryOnAppStartMeasurementAvailable)onAppStartMeasurementAvailable
{
    _onAppStartMeasurmentAvailable = onAppStartMeasurementAvailable;
}

@end
