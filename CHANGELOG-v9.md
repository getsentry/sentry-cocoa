# 9.0

### Breaking Changes

Removes deprecated SentryDebugImageProvider class (#5598)
Makes app hang tracking V2 the default and removes the option to enable/disable it (#5615)
Removes `integrations` property from `SentryOptions` (#5749)
Makes `SentryEventDecodable` internal (#5808)
The `span` property on `SentryScope` is now readonly (#5866)
