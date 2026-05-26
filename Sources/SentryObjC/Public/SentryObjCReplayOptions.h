#import "SentryObjCReplayQuality.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentryObjCReplayOptions : NSObject

@property (nonatomic) float sessionSampleRate;
@property (nonatomic) float onErrorSampleRate;
@property (nonatomic) BOOL maskAllText;
@property (nonatomic) BOOL maskAllImages;
@property (nonatomic) SentryObjCReplayQuality quality;
@property (nonatomic) BOOL enableViewRendererV2;
@property (nonatomic) BOOL enableFastViewRendering;
@property (nonatomic, copy) NSArray<Class> *maskedViewClasses;
@property (nonatomic, copy) NSArray<Class> *unmaskedViewClasses;
@property (nonatomic) BOOL networkCaptureBodies;
@property (nonatomic, copy) NSArray<NSString *> *networkRequestHeaders;
@property (nonatomic, copy) NSArray<NSString *> *networkResponseHeaders;

- (instancetype)init;

- (void)excludeViewTypeFromSubtreeTraversal:(NSString *)viewType;
- (void)includeViewTypeInSubtreeTraversal:(NSString *)viewType;

@end

NS_ASSUME_NONNULL_END
