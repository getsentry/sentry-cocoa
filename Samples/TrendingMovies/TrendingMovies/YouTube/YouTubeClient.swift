import Foundation

class YouTubeClient {
    enum ThumbnailType: String {
        case playerBackground = "0"
        case start = "1"
        case middle = "2"
        case end = "3"
        case highQuality = "hqdefault"
        case mediumQuality = "mqdefault"
        case normalQuality = "default"
        case standardDefinition = "sddefault"
        case maximumResolution = "maxresdefault"
    }

    /// Gets the thumbnail URL for a video.
    ///
    /// Based on: https://stackoverflow.com/a/20542029
    ///
    /// - Parameters:
    ///   - videoID: The ID of the video to get a thumbnail for.
    ///   - type: The thumbnail type.
    /// - Returns: URL to the thumbnail.
    static func getThumbnailURL(videoID: String, type: ThumbnailType) -> URL? {
        URL(string: "https://img.youtube.com/vi/\(videoID)/\(type.rawValue).jpg")
    }

    /// Get the YouTube web URL for a video ID.
    ///
    /// - Parameter videoID: The video ID to get a URL for.
    /// - Returns: The YouTube web (watch) URL.
    static func getVideoURL(videoID: String) -> URL? {
        URL(string: "https://www.youtube.com/watch?v=" + videoID)
    }
}
