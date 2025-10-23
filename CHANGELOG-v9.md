# 9.0

### Breaking Changes

Removes deprecated SentryDebugImageProvider class (#5598)
Makes app hang tracking V2 the default and removes the option to enable/disable it (#5615)
Removes segment property on SentryUser, SentryBaggage, and SentryTraceContext (#5638)
Removes public SentrySerializable conformance from many public models (#5636, #5840, #5982)
Removes `integrations` property from `SentryOptions` (#5749)
Makes `SentryEventDecodable` internal (#5808)
The `span` property on `SentryScope` is now readonly (#5866)
