# Develop Documentation

This is a collection of documents that can help you develop for the SentrySDK.

- ARCHITECTURE.md: the high-level concepts, features and organization of the codebase
- SWIFT.md: how we handle the intricacies when mixing Swift and ObjC/++
- TEST.md: unit testing, UI testing and static/runtime analysis
- BUILD.md: how we configure and build our SDK deliverables
- RELEASE.md: our release processes and best practices
- SDK_HISTORY.md: historical context and FAQ for the SDK
- [Language Trends Report](https://getsentry.github.io/sentry-cocoa/language-trends.html): interactive chart of the repository's language breakdown over time, updated on every merge to main via GitHub Pages

## GitHub Pages

We use [GitHub Pages](https://getsentry.github.io/sentry-cocoa/) to host generated developer reports. The site is deployed automatically by the [Analyze Language Trends](../.github/workflows/analyze-language-trends.yml) workflow, which builds the report and pushes it via `actions/upload-pages-artifact` + `actions/deploy-pages`. Pages is configured to deploy from GitHub Actions (Settings > Pages > Source > "GitHub Actions"). Currently the only report hosted there is the language trends analysis; more reports can be added by extending the site preparation step in the workflow.
