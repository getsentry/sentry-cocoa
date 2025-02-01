import Foundation

extension Bundle {
    /// Checks to make sure the app provides the NSPhotoLibraryUsageDescription Info plist key to request authorization. If the key is not present, trying to interact with certain Photos APIs will crash the app.
    var canRequestAuthorizationToAttachPhotos: Bool {
        Bundle.main.infoDictionary?["NSPhotoLibraryUsageDescription"] != nil
    }
}
