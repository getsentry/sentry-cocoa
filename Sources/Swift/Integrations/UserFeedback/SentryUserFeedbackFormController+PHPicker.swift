#if os(iOS) && !SENTRY_NO_UI_FRAMEWORK
internal import _SentryPrivate
internal import PhotosUI
import Foundation
import UIKit
import UniformTypeIdentifiers

private enum ScreenshotLoadingError: Error {
    case loadFailed(String)
    case tooLarge(UInt)

    var logLevel: SentryLevel {
        switch self {
        case .loadFailed: return .error
        case .tooLarge: return .warning
        }
    }

    var logMessage: String {
        switch self {
        case .loadFailed(let details):
            return "Failed to load a screenshot selected for user feedback: \(details)"
        case .tooLarge(let maxAttachmentSize):
            return "The screenshot selected for user feedback is larger than the maximum attachment size of \(maxAttachmentSize) bytes."
        }
    }

    var userMessage: String {
        switch self {
        case .loadFailed: return "The selected screenshot couldn't be loaded."
        case .tooLarge: return "The selected screenshot is too large to attach."
        }
    }
}

private final class ScreenshotPickerDelegate: NSObject, PHPickerViewControllerDelegate {
    private let animations: Bool
    private let didDismiss: ([PHPickerResult]) -> Void

    init(animations: Bool, didDismiss: @escaping ([PHPickerResult]) -> Void) {
        self.animations = animations
        self.didDismiss = didDismiss
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: animations) { [didDismiss] in
            didDismiss(results)
        }
    }
}

extension SentryUserFeedbackFormController {
    func makeScreenshotPicker() -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        configuration.selectionLimit = 1
        // Preserve the original bytes and metadata instead of requesting a conversion.
        configuration.preferredAssetRepresentationMode = .current
        let picker = PHPickerViewController(configuration: configuration)
        let delegate = ScreenshotPickerDelegate(animations: config.animations) { [weak self] results in
            guard let self = self else { return }
            self.screenshotPickerHandler = nil
            self.processScreenshotPickerResults(results)
        }
        screenshotPickerHandler = delegate
        picker.delegate = delegate
        return picker
    }

    private func processScreenshotPickerResults(_ results: [PHPickerResult]) {
        guard let result = results.first else { return }

        let provider = result.itemProvider
        guard let type = provider.registeredTypeIdentifiers.compactMap(UTType.init).first(where: {
            $0.conforms(to: .image)
        }) else {
            presentScreenshotError(message: "The selected item isn't a supported image.")
            return
        }

        let suggestedName = provider.suggestedName.flatMap { $0.isEmpty ? nil : $0 } ?? "screenshot"
        let filename: String
        if (suggestedName as NSString).pathExtension.isEmpty,
            let fileExtension = type.preferredFilenameExtension {
            filename = "\(suggestedName).\(fileExtension)"
        } else {
            filename = suggestedName
        }
        let contentType = type.preferredMIMEType
        // Forms can be created before the SDK has a client.
        let maxAttachmentSize = SentrySDKInternal.currentHub().getClient()?.options.maxAttachmentSize
            ?? Options().maxAttachmentSize

        loadScreenshot(
            from: provider,
            typeIdentifier: type.identifier,
            filename: filename,
            contentType: contentType,
            maxAttachmentSize: maxAttachmentSize
        )
    }

    private func loadScreenshot(
        from provider: NSItemProvider,
        typeIdentifier: String,
        filename: String,
        contentType: String?,
        maxAttachmentSize: UInt
    ) {
        viewModel.setScreenshotLoading(true)
        provider.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { [weak self] url, error in
            let result = Self.loadSelectedScreenshot(
                from: url,
                error: error,
                filename: filename,
                contentType: contentType,
                maxAttachmentSize: maxAttachmentSize
            )
            Dependencies.dispatchQueueWrapper.dispatchAsyncOnMainQueueIfNotMainThread { [weak self] in
                self?.finishLoadingScreenshot(result)
            }
        }
    }

    private static func loadSelectedScreenshot(
        from url: URL?,
        error: Error?,
        filename: String,
        contentType: String?,
        maxAttachmentSize: UInt
    ) -> Result<(UIImage, Attachment), ScreenshotLoadingError> {
        if let error = error {
            return .failure(.loadFailed(error.localizedDescription))
        }
        guard let url = url else {
            return .failure(.loadFailed("The item provider returned no file URL."))
        }

        do {
            // Avoid loading known oversized files, then verify the actual data size.
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            if let fileSize = attributes[.size] as? NSNumber,
                fileSize.uint64Value > UInt64(maxAttachmentSize) {
                return .failure(.tooLarge(maxAttachmentSize))
            }

            let data = try Data(contentsOf: url)
            guard UInt(data.count) <= maxAttachmentSize else {
                return .failure(.tooLarge(maxAttachmentSize))
            }
            guard let image = UIImage(data: data) else {
                return .failure(.loadFailed("The selected file didn't contain valid image data."))
            }
            return .success((image, Attachment(data: data, filename: filename, contentType: contentType)))
        } catch {
            return .failure(.loadFailed(error.localizedDescription))
        }
    }

    private func finishLoadingScreenshot(_ result: Result<(UIImage, Attachment), ScreenshotLoadingError>) {
        viewModel.setScreenshotLoading(false)
        switch result {
        case .success(let value):
            viewModel.setScreenshot(image: value.0, attachment: value.1)
        case .failure(let error):
            SentrySDKLog.log(message: error.logMessage, andLevel: error.logLevel)
            presentScreenshotError(message: error.userMessage)
        }
    }

    private func presentScreenshotError(message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: config.animations)
    }
}
#endif
