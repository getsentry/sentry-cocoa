import AVFoundation
import Sentry
import UIKit

class ViewController: UIViewController {

    @IBOutlet weak var backgroundLabel: UILabel!

    private weak var previewView: PreviewView!
    private weak var errorLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()

        setupBackgroundLabel()
        setupPreviewView()
        setupErrorLabel()
        setupCameraPreviewSession()
    }

    private func setupBackgroundLabel() {
        backgroundLabel.sentryReplayUnmask()
    }

    private func setupPreviewView() {
        let previewView = PreviewView()
        self.previewView = previewView
        view.addSubview(previewView)

        previewView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            previewView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            previewView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            previewView.topAnchor.constraint(equalTo: view.topAnchor),
            previewView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func setupErrorLabel() {
        let errorLabel = UILabel()
        self.errorLabel = errorLabel
        errorLabel.textColor = .white
        errorLabel.textAlignment = .center
        view.addSubview(errorLabel)

        errorLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            errorLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            errorLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        self.errorLabel = errorLabel
    }

    private func setupCameraPreviewSession() {
        let videoPreviewLayer = previewView.videoPreviewLayer

        // Check if the device has a camera
        let captureSession = AVCaptureSession()
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            errorLabel.text = "No camera available"
            return
        }

        // Create a video input from the camera
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

        // Assign the video output to the preview layer and start the session
        videoPreviewLayer.session = captureSession
        captureSession.startRunning()
    }
}
