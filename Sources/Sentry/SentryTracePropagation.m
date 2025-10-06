#import <SentryBaggage.h>
#import <SentryLogC.h>
#import <SentrySwift.h>
#import <SentryTraceHeader.h>
#import <SentryTracePropagation.h>

static NSString *const SENTRY_TRACEPARENT = @"traceparent";

@implementation SentryTracePropagation

+ (void)addBaggageHeader:(SentryBaggage *)baggage
                traceHeader:(SentryTraceHeader *)traceHeader
       propagateTraceparent:(BOOL)propagateTraceparent
    tracePropagationTargets:(NSArray *)tracePropagationTargets
                  toRequest:(NSURLSessionTask *)sessionTask
{
    if (![SentryTracePropagation sessionTaskRequiresPropagation:sessionTask
                                        tracePropagationTargets:tracePropagationTargets]) {
        SENTRY_LOG_DEBUG(@"Not adding trace_id and baggage headers for %@",
            sessionTask.currentRequest.URL.absoluteString);
        return;
    }
    NSString *baggageHeader = @"";

    if (baggage != nil) {
        NSDictionary *originalBaggage = [SentryBaggageSerialization
            decode:sessionTask.currentRequest.allHTTPHeaderFields[SENTRY_BAGGAGE_HEADER]];

        if (originalBaggage[@"sentry-trace_id"] == nil) {
            baggageHeader = [baggage toHTTPHeaderWithOriginalBaggage:originalBaggage];
        }
    }

    // First we check if the current request is mutable, so we could easily add a new
    // header. Otherwise we try to change the current request for a new one with the extra
    // header.
    if ([sessionTask.currentRequest isKindOfClass:[NSMutableURLRequest class]]) {
        NSMutableURLRequest *currentRequest = (NSMutableURLRequest *)sessionTask.currentRequest;
        [SentryTracePropagation addHeaderFieldsToRequest:currentRequest
                                             traceHeader:traceHeader
                                           baggageHeader:baggageHeader
                                    propagateTraceparent:propagateTraceparent];
    } else {
        // Even though NSURLSessionTask doesn't have 'setCurrentRequest', some subclasses
        // do. For those subclasses we replace the currentRequest with a mutable one with
        // the additional trace header. Since NSURLSessionTask is a public class and can be
        // override, we believe this is not considered a private api.
        SEL setCurrentRequestSelector = NSSelectorFromString(@"setCurrentRequest:");
        if ([sessionTask respondsToSelector:setCurrentRequestSelector]) {
            NSMutableURLRequest *newRequest = [sessionTask.currentRequest mutableCopy];
            [SentryTracePropagation addHeaderFieldsToRequest:newRequest
                                                 traceHeader:traceHeader
                                               baggageHeader:baggageHeader
                                        propagateTraceparent:propagateTraceparent];

            void (*func)(id, SEL, id param)
                = (void *)[sessionTask methodForSelector:setCurrentRequestSelector];
            func(sessionTask, setCurrentRequestSelector, newRequest);
        }
    }
}

+ (BOOL)sessionTaskRequiresPropagation:(NSURLSessionTask *)sessionTask
               tracePropagationTargets:(NSArray *)tracePropagationTargets
{
    return sessionTask.currentRequest != nil &&
        [SentryTracePropagation isTargetMatch:sessionTask.currentRequest.URL
                                  withTargets:tracePropagationTargets];
}

+ (void)addHeaderFieldsToRequest:(NSMutableURLRequest *)request
                     traceHeader:(SentryTraceHeader *)traceHeader
                   baggageHeader:(NSString *)baggageHeader
            propagateTraceparent:(BOOL)propagateTraceparent
{
    if ([request valueForHTTPHeaderField:SENTRY_TRACE_HEADER] == nil) {
        [request setValue:traceHeader.value forHTTPHeaderField:SENTRY_TRACE_HEADER];
    }

    if (propagateTraceparent && [request valueForHTTPHeaderField:SENTRY_TRACEPARENT] == nil) {

        NSString *traceparent = [NSString stringWithFormat:@"00-%@-%@-%02x",
            traceHeader.traceId.sentryIdString, traceHeader.spanId.sentrySpanIdString,
            traceHeader.sampled == kSentrySampleDecisionYes ? 1 : 0];

        [request setValue:traceparent forHTTPHeaderField:SENTRY_TRACEPARENT];
    }

    if (baggageHeader.length > 0) {
        [request setValue:baggageHeader forHTTPHeaderField:SENTRY_BAGGAGE_HEADER];
    }
}

+ (BOOL)isTargetMatch:(NSURL *)URL withTargets:(NSArray *)targets
{
    for (id targetCheck in targets) {
        if ([targetCheck isKindOfClass:[NSRegularExpression class]]) {
            NSString *string = URL.absoluteString;
            NSUInteger numberOfMatches =
                [targetCheck numberOfMatchesInString:string
                                             options:0
                                               range:NSMakeRange(0, [string length])];
            if (numberOfMatches > 0) {
                return YES;
            }
        } else if ([targetCheck isKindOfClass:[NSString class]]) {
            if ([URL.absoluteString containsString:targetCheck]) {
                return YES;
            }
        }
    }

    return NO;
}

@end
