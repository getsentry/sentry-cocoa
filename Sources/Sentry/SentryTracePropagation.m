#import <SentryBaggage.h>
#import <SentryLogC.h>
#import <SentrySwift.h>
#import <SentryTraceHeader.h>
#import <SentryTracePropagation.h>

@implementation SentryTracePropagation

+ (void)addBaggageHeader:(SentryBaggage *)baggage
                traceHeader:(SentryTraceHeader *)traceHeader
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

        if ([currentRequest valueForHTTPHeaderField:SENTRY_TRACE_HEADER] == nil) {
            [currentRequest setValue:traceHeader.value forHTTPHeaderField:SENTRY_TRACE_HEADER];
        }

        if (baggageHeader.length > 0) {
            [currentRequest setValue:baggageHeader forHTTPHeaderField:SENTRY_BAGGAGE_HEADER];
        }
    } else {
        // Even though NSURLSessionTask doesn't have 'setCurrentRequest', some subclasses
        // do. For those subclasses we replace the currentRequest with a mutable one with
        // the additional trace header. Since NSURLSessionTask is a public class and can be
        // override, we believe this is not considered a private api.
        SEL setCurrentRequestSelector = NSSelectorFromString(@"setCurrentRequest:");
        if ([sessionTask respondsToSelector:setCurrentRequestSelector]) {
            NSMutableURLRequest *newRequest = [sessionTask.currentRequest mutableCopy];

            if ([newRequest valueForHTTPHeaderField:SENTRY_TRACE_HEADER] == nil) {
                [newRequest setValue:traceHeader.value forHTTPHeaderField:SENTRY_TRACE_HEADER];
            }

            if (baggageHeader.length > 0) {
                [newRequest setValue:baggageHeader forHTTPHeaderField:SENTRY_BAGGAGE_HEADER];
            }

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
