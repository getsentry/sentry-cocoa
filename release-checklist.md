# Release Checklist

  - [ ] Bump version in podspec file
  - [ ] Bump version in framework xcode targets
  - [ ] Bump version in `Sentry.swift`
  - [ ] Ensure all needed changes are checked in the master branch
  - [ ] Run `make release`
  - [ ] `pod spec lint` and add new version to cocoapods repo
  - [ ] Push new podspec version to master repo `pod trunk push SentrySwift.podspec --allow-warnings`
  - [ ] Create a version tag
  - [ ] Update sentry-docs
  - [ ] Write down changes on github in releases
  - [ ] Upload SentrySwift.Framework.zip to github release