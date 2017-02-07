# Release Checklist

  - [ ] Bump version in podspec file
  - [ ] Bump version in framework xcode targets
  - [ ] Bump version in `Sentry.swift`
  - [ ] Bump version in `docs/sentry-doc-config.json`
  - [ ] Run `make release`
  - [ ] Ensure all needed changes are checked in the master branch
  - [ ] Create a version tag
  - [ ] Update `docs/`
  - [ ] Push new podspec version to master repo `pod trunk push Sentry.podspec --allow-warnings`
  - [ ] Write down changes on github in releases
  - [ ] Upload Sentry.Framework.zip to github release
