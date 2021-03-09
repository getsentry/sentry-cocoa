#import <Foundation/Foundation.h>
#import "SentrySampleDecision.h"

NS_ASSUME_NONNULL_BEGIN

@class SentryOptions, SentrySamplingContext;

@interface TracesSampler : NSObject

/**
 *  A value than can be used for test purpose.
 */
@property (nonatomic, strong) NSNumber *definedRandom;

/**
 * Init a TracesSampler with given options.
 */
- (instancetype)initWithOptions:(SentryOptions *)options;

/**
 * Determines whether a trace should be sampled based on the context and options.
 */
- (SentrySampleDecision)sample:(SentrySamplingContext *)context;

@end

NS_ASSUME_NONNULL_END
