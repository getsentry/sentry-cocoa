import CoreLocation
import UIKit

class PermissionsViewController: UIViewController {
    private let locationManager = CLLocationManager()

    private lazy var pushPermissionButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Request Push Permission", for: .normal)
        button.addTarget(self, action: #selector(requestPushPermission), for: .touchUpInside)

        return button
    }()

    private lazy var locationPermissionButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Request Location Permission", for: .normal)
        button.addTarget(self, action: #selector(requestLocationPermission), for: .touchUpInside)
        return button
    }()

    private lazy var stackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [pushPermissionButton, locationPermissionButton])
        stackView.axis = .vertical
        stackView.spacing = 10
        stackView.alignment = .center
        return stackView.forAutoLayout()
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()

        locationManager.delegate = self

        UNUserNotificationCenter.current().getNotificationSettings { settings in
            print("Initial push permission status: \(settings.authorizationStatus)")
        }

        print("Initial location permission status: \(CLLocationManager.authorizationStatus())")
    }

    private func setupView() {
        view.backgroundColor = .white
        view.addSubview(stackView)

        let constraints = [
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ]

        NSLayoutConstraint.activate(constraints)
    }

    @objc func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        SentrySDK.reportFullyDisplayed()
    }

    @objc func requestPushPermission() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                if let error = error {
                    print(error)
                }
                print(granted)
            }
    }
}

extension PermissionsViewController: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        print("Status updated to: \(status)")
    }
}
