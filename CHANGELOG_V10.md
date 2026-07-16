# Changelog

## Unreleased

### Features

- Add `options.dataCollection` to configure data collection behaviour (#8448)
- Add dictionary initialization for `options.dataCollection` (#8371)

### Breaking Changes

- Remove Objective-C `@objc` attributes from SentrySDK (#8308)
- Remove deprecated `locale` from device context; use `locale` in culture context instead (#8325)

### Fixes

- Normalize profiling CPU usage to 0–100 percent (#8323)
