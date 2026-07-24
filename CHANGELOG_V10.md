# Changelog

## Unreleased

### Features

- Add `options.dataCollection` to configure data collection behaviour (#8448)
  - Allows dictionary initialization for `options.dataCollection` (#8371)
  - Renamed `options.dataCollection.queryParams` to `options.dataCollection.urlQueryParams` (#8414)
  - Add query parameter filtering for network spans, breadcrumbs, and failed requests using `options.dataCollection.urlQueryParams` (#8414)
  - Enable automatic user information for logs, metrics, and IP inference by default; configure it with `options.dataCollection.userInfo` (#8254)
  - Gate Session Replay request and response body capture with `options.dataCollection.httpBodies`, and scrub sensitive body values (#8250)

### Breaking Changes

- Remove Objective-C `@objc` attributes from SentrySDK (#8308)
- Remove deprecated `locale` from device context; use `locale` in culture context instead (#8325)
- Change `SentryReplayOptions.networkCaptureBodies` from `Bool` to `SentryReplayOptions.NetworkBodyCapture`.
  Use `.inherit` to follow `dataCollection.httpBodies`, `.enabled` to capture all Replay network bodies, or `.disabled` to capture none (#8250)

### Fixes

- Normalize profiling CPU usage to 0–100 percent (#8323)
