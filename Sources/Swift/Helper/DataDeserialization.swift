@_spi(Private) @objc public final class DataDeserialization: NSObject {
    @objc(sessionWithData:) public static func session(with data: Data) -> SentrySession? {
        do {
            guard let sessionDictionary = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let session = SentrySession(jsonObject: sessionDictionary) else {
                SentrySDKLog.error("Failed to initialize session from dictionary. Dropping it.")
                return nil
            }

            guard let releaseName = session.releaseName, !releaseName.isEmpty else {
                SentrySDKLog.error("Deserialized session doesn't contain a release name. Dropping it.")
                return nil
            }
            return session
        } catch {
            SentrySDKLog.error("Failed to deserialize session data \(error)")
            return nil
        }
    }

    @objc(appStateWithData:) public static func appState(with data: Data) -> SentryAppState? {
      do {
          guard let appStateDictionary = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
              return nil
          }
          return SentryAppState(jsonObject: appStateDictionary)
      } catch {
        SentrySDKLog.error("Failed to deserialize app state data \(error)")
        return nil
      }
    }
}
