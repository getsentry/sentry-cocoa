# Changelog

## Unreleased

### Breaking Changes

- Remove Objective-C `@objc` attributes from SentrySDK (#8308)
- Remove deprecated `locale` from device context; use `locale` in culture context instead (#8325)

### Fixes

- Normalize profiling CPU usage to 0–100 percent (#8323)
