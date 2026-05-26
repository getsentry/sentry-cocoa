# Feedback API PR Adaptation TODO

## Step 1 — Resolve presentation delegate review feedback

- [x] In `SentryUIKitFeedbackFormPresenter`, assign `presentationController?.delegate` after `present(...)` is called, but not in the completion handler.
- [x] Re-check PR review comments and confirm both delegate-timing concerns are addressed.

## Step 2 — Decide final public API names

- [x] Align naming with the cross-SDK direction: prefer `show` / `showFeedback` over `presentForm`.
- [x] Decide whether Cocoa exposes:
  - `SentrySDK.feedback.show(...)`, or
  - `SentrySDK.showFeedback(...)`, or both with one as convenience.
  - Decision: use `SentrySDK.feedback.show(...)` for now.
- [x] Keep “Form” terminology for new API/docs; avoid new “Widget” naming.
- [x] Remove `presentForm` compatibility aliases because those APIs were only added on this unreleased PR branch.

## Step 3 — Expose a public feedback form controller

- [ ] Make the feedback form controller public API.
- [ ] Provide a public initializer that accepts per-instance configuration.
- [ ] Ensure manual UIKit presentation works without configuring feedback in SDK init options.
- [ ] Ensure ObjC access for the public API.
- [ ] Update `sdk_api.json` after public API changes.

## Step 4 — Decouple configuration from SDK init for manual forms

- [ ] Move the recommended customization path to per-form configuration.
- [ ] Keep existing `Options.configureUserFeedback` for backward compatibility.
- [ ] Mark old init-time/widget-specific configuration APIs deprecated only if agreed for this PR.
- [ ] Ensure submit/cancel/open/close callbacks still work for manually-created forms.

## Step 5 — Rework convenience presentation APIs

- [ ] Implement no-arg convenience API using the public form controller internally.
- [x] Do not expose public anchored helpers (`show(from:)` / `show(in:)`); standalone VC presentation is the explicit-anchor API.
- [ ] Keep no-arg convenience API only, but document that it picks an available scene/window and is not guaranteed for multi-window/external-display cases.
- [ ] Keep scene/window/controller resolving logic internal for legacy widget, shake, screenshot, and no-arg convenience flows only.
- [ ] Make sure active presenter state is cleared after cancel, submit, programmatic dismiss, and swipe dismiss.

## Step 6 — SwiftUI API

- [ ] Prefer a SwiftUI-native/manual presentation example using `.sheet`.
- [ ] Keep or revise `.sentryFeedbackForm()` only if it still fits the final API direction.
- [ ] Add a SwiftUI wrapper around the public form controller if needed.

## Step 7 — Widget/FAB deprecation plan

- [ ] Keep current widget/FAB behavior for compatibility.
- [ ] Deprecate `showWidget` / `hideWidget` only if approved for this PR.
- [ ] Update comments/docs to clarify that widget/FAB is legacy/convenience and mobile-antipattern.
- [ ] Add major-version removal follow-up if deprecation lands.

## Step 8 — Samples

- [ ] UIKit sample: manual `FeedbackForm` presentation from a view controller.
- [ ] UIKit sample: convenience API from a button/settings screen.
- [ ] SwiftUI sample: `.sheet` with feedback form.
- [ ] Shake-to-feedback sample/configuration.

## Step 9 — Documentation and comments

- [ ] Update API docs to use “form” terminology.
- [ ] Document multi-window/external-display edge cases on no-arg convenience API.
- [ ] Show manual presentation as the preferred iOS path.
- [ ] Remove or reduce FAB/widget-first docs references.

## Step 10 — Verification

- [ ] Run targeted feedback tests.
- [ ] Run sample build if sample code changes.
- [ ] Run public API generation if public API changes.
- [ ] Run formatting before finalizing.
