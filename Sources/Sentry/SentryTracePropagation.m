#import <SentryBaggage.h>
#import <SentryInternalDefines.h>
#import <SentryLogC.h>
#import <SentrySwift.h>
#import <SentryTraceHeader.h>
#import <SentryTracePropagation.h>

static NSString *const SENTRY_TRACEPARENT = @"traceparent";

@implementation SentryTracePropagation

+ (void)addBaggageHeader:(SentryBaggage *)baggage
                traceHeader:(SentryTraceHeader *)traceHeader
       propagateTraceparent:(BOOL)propagateTraceparent
    tracePropagationTargets:(NSArray *_Nullable)tracePropagationTargets
                  toRequest:(NSURLSessionTask *)sessionTask
{
    // Snapshot currentRequest once — the property is volatile and can become a zombie
    // between repeated accesses if the task completes on another thread.
    NSURLRequest *request = sessionTask.currentRequest;
    if (request == nil) {
        return;
    }

    if (![SentryTracePropagation isTargetMatch:SENTRY_UNWRAP_NULLABLE(NSURL, request.URL)
                                   withTargets:tracePropagationTargets ?: @[]]) {
        SENTRY_LOG_DEBUG(
            @"Not adding trace_id and baggage headers for %@", request.URL.absoluteString);
        return;
    }
    NSString *baggageHeader = @"";

    if (baggage != nil) {
        NSString *_Nullable rawHeader
            = SENTRY_UNWRAP_NULLABLE(NSString, request.allHTTPHeaderFields[SENTRY_BAGGAGE_HEADER]);
        NSDictionary *originalBaggage = [SentryBaggageSerialization decode:rawHeader ?: @""];
        if (originalBaggage[@"sentry-trace_id"] == nil) {
            baggageHeader = [baggage toHTTPHeaderWithOriginalBaggage:originalBaggage];
        }
    }

    if ([request isKindOfClass:[NSMutableURLRequest class]]) {
        NSMutableURLRequest *mutableRequest = (NSMutableURLRequest *)request;
        [SentryTracePropagation addHeaderFieldsToRequest:mutableRequest
                                             traceHeader:traceHeader
                                           baggageHeader:baggageHeader
                                    propagateTraceparent:propagateTraceparent];
    } else {
        SEL setCurrentRequestSelector = NSSelectorFromString(@"setCurrentRequest:");
        if ([sessionTask respondsToSelector:setCurrentRequestSelector]) {
            NSMutableURLRequest *newRequest = [request mutableCopy];
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
        [SentryTracePropagation
            isTargetMatch:SENTRY_UNWRAP_NULLABLE(NSURL, sessionTask.currentRequest.URL)
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
