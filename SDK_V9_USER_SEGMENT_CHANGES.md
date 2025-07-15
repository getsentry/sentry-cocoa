# SDK_V9 UserSegment Changes

## Problem
When building with `SDK_V9` enabled, the files `SentryNetworkTracker.m` and `SentryClient.m` were passing `nil` as the argument to `userSegment` when calling the `SentryTraceContext` initializer. This was inefficient and potentially confusing.

## Solution
Updated the `SentryTraceContext` initializer to not take the `userSegment` parameter at all when `SDK_V9` is enabled.

## Changes Made

### 1. SentryTraceContext.h
- Added a new conditional initializer for `SDK_V9` that doesn't include the `userSegment` parameter:
```objc
#if SDK_V9
- (instancetype)initWithTraceId:(SentryId *)traceId
                        options:(SentryOptions *)options
                       replayId:(nullable NSString *)replayId;
#endif // SDK_V9
```

### 2. SentryTraceContext.m
- Implemented the new `SDK_V9` initializer that internally passes `nil` for `userSegment`:
```objc
#if SDK_V9
- (instancetype)initWithTraceId:(SentryId *)traceId
                        options:(SentryOptions *)options
                       replayId:(nullable NSString *)replayId
{
    return [[SentryTraceContext alloc] initWithTraceId:traceId
                                             publicKey:options.parsedDsn.url.user
                                           releaseName:options.releaseName
                                           environment:options.environment
                                           transaction:nil
                                           userSegment:nil
                                            sampleRate:nil
                                            sampleRand:nil
                                               sampled:nil
                                              replayId:replayId];
}
#endif // SDK_V9
```

### 3. SentryNetworkTracker.m
- Updated `addTraceWithoutTransactionToTask:` method to use conditional compilation:
  - When `SDK_V9` is enabled: calls the new initializer without `userSegment`
  - When `SDK_V9` is disabled: calls the original initializer with `userSegment`

### 4. SentryClient.m
- Updated `getTraceStateWithEvent:withScope:` method to use conditional compilation:
  - When `SDK_V9` is enabled: calls the new initializer without `userSegment`
  - When `SDK_V9` is disabled: calls the original initializer with `userSegment`

## Benefits
1. **Cleaner API**: When `SDK_V9` is enabled, the API doesn't expose deprecated `userSegment` parameter
2. **Type Safety**: Eliminates the need to pass `nil` explicitly
3. **Backward Compatibility**: Maintains full compatibility when `SDK_V9` is not enabled
4. **Clear Intent**: Makes it explicit that `userSegment` is not used in `SDK_V9`

## Files Modified
- `/workspace/Sources/Sentry/Public/SentryTraceContext.h`
- `/workspace/Sources/Sentry/SentryTraceContext.m`
- `/workspace/Sources/Sentry/SentryNetworkTracker.m`
- `/workspace/Sources/Sentry/SentryClient.m`

## Verification
All instances of `SentryTraceContext` initialization have been checked to ensure no other locations needed updates. The changes are isolated to the two problematic locations mentioned in the issue.