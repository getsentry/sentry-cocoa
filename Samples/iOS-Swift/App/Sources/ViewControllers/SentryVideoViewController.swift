import AVKit
import UIKit

/// Video view controller for displaying video using the ``AVKit`` framework.
///
/// See the expo-video video view for reference:
/// https://github.com/expo/expo/blob/sdk-53/packages/expo-video/ios/VideoView.swift
class SentryVideoViewController: UIViewController {
    lazy var playerViewController = AVPlayerViewController()

    weak var player: AVPlayer? {
        didSet {
            playerViewController.player = player
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupPlayerUI()
        setupPlayer()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Start playing the video when the view appears.
        player?.play()
    }

    func setupPlayerUI() {
        // Use a distinct color to clearly indicate when the video content not being displayed.
        playerViewController.view.backgroundColor = .systemOrange

        // Disable updates to the Now Playing Info Center, to increase isolation of app to global system state.
        playerViewController.updatesNowPlayingInfoCenter = false

        // Reference for the correct life cycle calls:
        // https://developer.apple.com/documentation/uikit/creating-a-custom-container-view-controller#Add-a-child-view-controller-programmatically-to-your-content
        addChild(playerViewController)
        view.addSubview(playerViewController.view)

        playerViewController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            playerViewController.view.topAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.topAnchor),
            playerViewController.view.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),

            playerViewController.view.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            playerViewController.view.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor)
        ])

        playerViewController.didMove(toParent: self)
    }

    func setupPlayer() {
        guard let videoUrl = Bundle.main.url(forResource: "Sample", withExtension: "mp4") else {
            preconditionFailure("Sample video not found in main bundle")
        }
        let player = AVPlayer(url: videoUrl)
        player.isMuted = true
        self.player = player
    }
}
