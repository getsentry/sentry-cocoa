# Changelog

## Unreleased

### Features

- Add `options.dataCollection` to configure data collection behaviour (#8448)
  - Allows dictionary initialization for `options.dataCollection` (#8371)
  - Renamed `options.dataCollection.queryParams` to `options.dataCollection.urlQueryParams` (#8414)
  - Add query parameter filtering for network spans, breadcrumbs, and failed requests using `options.dataCollection.urlQueryParams` (#8414)
  - Enable automatic user information for logs, metrics, and IP inference by default; configure it with `options.dataCollection.userInfo` (#8254)
  - Add HTTP header and cookie filtering for failed requests using `options.dataCollection` (#8460)
  - Gate Session Replay request and response body capture with `options.dataCollection.httpBodies`, and scrub sensitive body values (#8547)

### Breaking Changes

- Remove Objective-C `@objc` attributes from SentrySDK (#8308)
- Remove deprecated `locale` from device context; use `locale` in culture context instead (#8325)
- Change `SentryRequest.cookies` from a string to a dictionary of cookie names and values (#8460)
- Change `SentryReplayOptions.networkCaptureBodies` from `Bool` to `SentryReplayOptions.NetworkBodyCapture`. (#8547)
  Use `.inherit` to follow `dataCollection.httpBodies`, `.enabled` to capture all Replay network bodies, or `.disabled` to capture none

### Fixes

- Normalize profiling CPU usage to 0–100 percent (#8323)
