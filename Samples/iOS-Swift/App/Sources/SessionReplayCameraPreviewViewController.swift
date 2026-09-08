import AVFoundation
import SentrySwift
import UIKit

final class SessionReplayCameraPreviewViewController: UIViewController {
    private let captureSession = AVCaptureSession()
    private let captureQueue = DispatchQueue(label: "io.sentry.session-replay-camera-preview")
    private let previewView = CameraPreviewView()
    private let errorLabel = UILabel()
    private var isCaptureSessionConfigured = false

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Camera Preview"
        view.backgroundColor = .systemOrange

        setupBackgroundLabel()
        setupPreviewView()
        setupErrorLabel()
        setupCameraPreviewSession()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        guard isCaptureSessionConfigured else { return }
        captureQueue.async { [captureSession] in
            captureSession.startRunning()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        guard isCaptureSessionConfigured else { return }
        captureQueue.async { [captureSession] in
            captureSession.stopRunning()
        }
    }

    private func setupBackgroundLabel() {
        let backgroundLabel = UILabel()
        backgroundLabel.text = "BACKGROUND"
        backgroundLabel.textColor = UIColor(
            displayP3Red: 0.5,
            green: 0.32074801106853668,
            blue: 0.11964321975700687,
            alpha: 1
        )
        backgroundLabel.font = UIFont(name: "CourierNewPS-BoldMT", size: 30)
        backgroundLabel.sentryReplayUnmask()
        view.addSubview(backgroundLabel)

        backgroundLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            backgroundLabel.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
            backgroundLabel.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor)
        ])
    }

    private func setupPreviewView() {
        previewView.accessibilityIdentifier = "session-replay-camera-preview"
        previewView.isAccessibilityElement = true
        view.addSubview(previewView)

        previewView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            previewView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            previewView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            previewView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            previewView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }

    private func setupErrorLabel() {
        errorLabel.textColor = .white
        errorLabel.textAlignment = .center
        view.addSubview(errorLabel)

        errorLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            errorLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            errorLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    private func setupCameraPreviewSession() {
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            errorLabel.text = "No camera available"
            return
        }

        let videoInput: AVCaptureDeviceInput
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            errorLabel.text = "Failed to create video input: \(error.localizedDescription)"
            return
        }

        guard captureSession.canAddInput(videoInput) else {
            errorLabel.text = "Failed to add video input to session"
            return
        }

        captureSession.addInput(videoInput)
        previewView.videoPreviewLayer.session = captureSession
        isCaptureSessionConfigured = true
    }
}

private final class CameraPreviewView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
}
