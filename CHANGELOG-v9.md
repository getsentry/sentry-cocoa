# 9.0

### Breaking Changes

Removes deprecated user feedback API, this is replaced with the new feedback API (#5591)
Removes unused SentryLogLevel (#5591)
Removes deprecated getStoreEndpoint (#5591)
Removes deprecated useSpan function (#5591)
Removes deprecated SentryDebugImageProvider class (#5598)
Makes app hang tracking V2 the default and removes the option to enable/disable it (#5615)
Removes segment property on SentryUser, SentryBaggage, and SentryTraceContext (#5638)
Removes public SentrySerializable conformance from many public models (#5636)
Removes Decodable conformances from the public API of model classes (#5691)
Removes enableTracing property from SentryOptions (#5694)

### Fixes

Fixes warnings about minimum OS version being lower than Xcode supported version (#5591)

### Improvements
