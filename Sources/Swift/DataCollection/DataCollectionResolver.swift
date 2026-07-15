/// Resolves automatic user information collection for Data Collection spec v0.6.0.
///
/// See https://develop.sentry.dev/sdk/foundations/client/data-collection/.
/// While `dataCollection` remains experimental in Cocoa, an untouched configuration
/// does not enable collection. Explicit `userInfo` takes precedence over the legacy
/// `sendDefaultPii` bridge.
struct DataCollectionResolver {
    static func resolveAutoInferIP(
        sendDefaultPii: SentryModifiable<Bool>,
        userInfo: SentryModifiable<Bool>
    ) -> Bool {
        if userInfo.isModified {
            return userInfo.value
        }

        if sendDefaultPii.isModified {
            return sendDefaultPii.value
        }

        return false
    }
}
