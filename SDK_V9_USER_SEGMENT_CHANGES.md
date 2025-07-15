# SDK_V9 UserSegment Changes

## Problem
When building with `SDK_V9` enabled, the files `SentryNetworkTracker.m` and `SentryClient.m` were passing `nil` as the argument to `userSegment` when calling the `SentryTraceContext` initializer. This was inefficient and potentially confusing.

## Solution
Updated the `SentryTraceContext` and `SentryBaggage` initializers to conditionally exclude the `userSegment` parameter entirely when `SDK_V9` is enabled using conditional compilation (`#if !SDK_V9`).

## Changes Made

### 1. SentryTraceContext.h
- Made the `userSegment` property conditional: only available when `SDK_V9` is not enabled
- Updated all initializers to conditionally exclude the `userSegment` parameter:
```objc
- (instancetype)initWithTraceId:(SentryId *)traceId
                        options:(SentryOptions *)options
#if !SDK_V9
                    userSegment:(nullable NSString *)userSegment
#endif
                       replayId:(nullable NSString *)replayId;
```

### 2. SentryTraceContext.m
- Updated all initializer implementations to conditionally handle `userSegment`:
  - When `SDK_V9` is not enabled: uses the passed `userSegment` parameter
  - When `SDK_V9` is enabled: automatically sets `userSegment` to `nil`
- Updated conditional parsing in `initWithDict:` method
- Updated conditional serialization in `serialize` method
- Updated `toBaggage` method to conditionally exclude `userSegment`

### 3. SentryBaggage.h
- Made the `userSegment` property conditional: only available when `SDK_V9` is not enabled
- Updated all initializers to conditionally exclude the `userSegment` parameter

### 4. SentryBaggage.m
- Updated all initializer implementations to conditionally handle `userSegment`
- Updated `toHTTPHeaderWithOriginalBaggage` method to conditionally exclude `userSegment` serialization

### 5. SentryNetworkTracker.m
- Updated `addTraceWithoutTransactionToTask:` method to:
  - Only retrieve and use `userSegment` when `SDK_V9` is not enabled
  - Call the initializer without `userSegment` parameter when `SDK_V9` is enabled

### 6. SentryClient.m
- Updated `getTraceStateWithEvent:withScope:` method to:
  - Only retrieve and use `userSegment` when `SDK_V9` is not enabled  
  - Call the initializer without `userSegment` parameter when `SDK_V9` is enabled

## Benefits
1. **Cleaner API**: When `SDK_V9` is enabled, the `userSegment` concept is completely removed from the API
2. **Type Safety**: No need to pass `nil` explicitly - the parameter doesn't exist
3. **Backward Compatibility**: Full compatibility maintained when `SDK_V9` is not enabled
4. **Consistent Approach**: Applied uniformly across `SentryTraceContext` and `SentryBaggage`
5. **No Runtime Overhead**: Conditional compilation means no runtime checks

## Files Modified
- `/workspace/Sources/Sentry/Public/SentryTraceContext.h`
- `/workspace/Sources/Sentry/SentryTraceContext.m`
- `/workspace/Sources/Sentry/Public/SentryBaggage.h`
- `/workspace/Sources/Sentry/SentryBaggage.m`
- `/workspace/Sources/Sentry/SentryNetworkTracker.m`
- `/workspace/Sources/Sentry/SentryClient.m`

## Verification
All instances of `SentryTraceContext` and `SentryBaggage` initialization have been updated. The `userSegment` field is completely excluded from the API when `SDK_V9` is enabled, providing a clean separation between SDK versions.