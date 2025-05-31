// Makes the `experimental` property visible as the Swift type `SentryExperimentalOptions`.
// This works around `SentryExperimentalOptions` being only forward declared in the objc header.
@objc
extension Options {

   /**
    * This aggregates options for experimental features.
    * Be aware that the options available for experimental can change at any time.
    */
    @objc
    open var experimental: SentryExperimentalOptions {
      // We know the type so it's fine to force cast.
      // swiftlint:disable force_cast
        _swiftExperimentalOptions as! SentryExperimentalOptions
      // swiftlint:enable force_cast
    }
}
