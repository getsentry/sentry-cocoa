#import "SentryDebugImageProvider.h"
#import "SentryHybridSDKsOnly.h"
#import "SentrySDK+Private.h"
#import "SentrySerialization.h"
#import <Foundation/Foundation.h>

@interface
SentryHybridSDKsOnly ()

@property (nonatomic, strong) SentryDebugImageProvider *debugImageProvider;

@end

@implementation SentryHybridSDKsOnly

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

+ (nullable SentryEnvelope *)envelopeWithData:(NSData *)data
{
    return [SentrySerialization envelopeWithData:data];
}

- (NSArray<SentryDebugMeta *> *)getDebugImages
{
    return [self.debugImageProvider getDebugImages];
}

@end
