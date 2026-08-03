#if os(iOS) && !SENTRY_NO_UI_FRAMEWORK
internal import _SentryPrivate
internal import PhotosUI
import Foundation
import UIKit
import UniformTypeIdentifiers

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
            SentrySDKLog.warning("The item selected for user feedback doesn't provide a supported image type.")
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
            let screenshot = Self.loadSelectedScreenshot(
                from: url,
                error: error,
                filename: filename,
                contentType: contentType,
                maxAttachmentSize: maxAttachmentSize
            )
            Dependencies.dispatchQueueWrapper.dispatchAsyncOnMainQueueIfNotMainThread { [weak self] in
                self?.finishLoadingScreenshot(screenshot)
            }
        }
    }

    private static func loadSelectedScreenshot(
        from url: URL?,
        error: Error?,
        filename: String,
        contentType: String?,
        maxAttachmentSize: UInt
    ) -> (UIImage, Attachment)? {
        if let error = error {
            SentrySDKLog.error("Failed to load a screenshot selected for user feedback: \(error.localizedDescription)")
            return nil
        }
        guard let url = url else {
            SentrySDKLog.error("The item provider returned no screenshot file URL for user feedback.")
            return nil
        }

        do {
            // Avoid loading known oversized files, then verify the actual data size.
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            if let fileSize = attributes[.size] as? NSNumber,
                fileSize.uint64Value > UInt64(maxAttachmentSize) {
                SentrySDKLog.warning("The screenshot selected for user feedback exceeds the maximum attachment size of \(maxAttachmentSize) bytes.")
                return nil
            }

            let data = try Data(contentsOf: url)
            guard UInt(data.count) <= maxAttachmentSize else {
                SentrySDKLog.warning("The screenshot selected for user feedback exceeds the maximum attachment size of \(maxAttachmentSize) bytes.")
                return nil
            }
            guard let image = UIImage(data: data) else {
                SentrySDKLog.error("The screenshot selected for user feedback doesn't contain valid image data.")
                return nil
            }
            return (image, Attachment(data: data, filename: filename, contentType: contentType))
        } catch {
            SentrySDKLog.error("Failed to load a screenshot selected for user feedback: \(error.localizedDescription)")
            return nil
        }
    }

    private func finishLoadingScreenshot(_ screenshot: (UIImage, Attachment)?) {
        viewModel.setScreenshotLoading(false)
        guard let screenshot = screenshot else { return }
        viewModel.setScreenshot(image: screenshot.0, attachment: screenshot.1)
    }
}
#endif
