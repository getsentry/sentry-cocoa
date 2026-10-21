## :scroll: Description

<!--- Describe your changes in detail and optionally add screenshots -->

## :bulb: Motivation and Context

<!--- Why is this change required? What problem does it solve? -->
<!--- If it fixes an open issue, please link to the issue here. -->

## Changelog Entry

<!--- For user-facing changes, describe the change for users. Craft adds this text to CHANGELOG.md at release time. -->
<!--- Without text here, Craft uses the PR title. To leave the PR out of the changelog, see CONTRIBUTING.md. -->

## :green_heart: How did you test it?

<!---
Include a link to Sentry when applicable:
* Link to Sentry: <LINK>
-->

## :pencil: Checklist

You have to check all boxes before merging:

- [ ] I added tests to verify the changes.
- [ ] No new PII added or SDK only sends newly added PII if `sendDefaultPII` is enabled.
- [ ] I updated the docs if needed.
- [ ] I updated the wizard if needed.
- [ ] Review from the native team if needed.
- [ ] No breaking change, or the breaking change is described under Changelog Entry.
- [ ] No breaking change for hybrid SDKs or communicated to hybrid SDKs.
- [ ] Public API changes reviewed by another Mobile SDK team member or implemented according to the [develop docs](https://develop.sentry.dev/) spec.
- [ ] If I added a new public API, I also added it to the [SentryObjC wrapper](../develop-docs/SENTRY-OBJC.md).
