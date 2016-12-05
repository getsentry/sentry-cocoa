# Release Checklist

  - [ ] Bump version in podspec file
  - [ ] Bump version in framework xcode targets
  - [ ] Ensure all needed changes are checked in the master branch
  - [ ] Run `make release`
  - [ ] `pod spec lint` and add new version to cocoapods repo
  - [ ] Create a version tag
  - [ ] Update to latest version in sentry-docs
  - [ ] Write down changes on github in releases
  - [ ] Upload SentrySwift.Framework.zip to github release