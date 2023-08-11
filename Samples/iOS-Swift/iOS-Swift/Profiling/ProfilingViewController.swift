import CoreBluetooth
import CoreLocation
import UIKit

@available(iOS 13.0, *)
class ProfilingViewController: UIViewController, CLLocationManagerDelegate, UITextFieldDelegate {

    @IBOutlet weak var workThreadLabel: UILabel!
    @IBOutlet weak var workIntensityFactorLabel: UILabel!
    @IBOutlet weak var minWorkIntensityLabel: UILabel!

    @IBOutlet weak var workThreadSlider: UISlider!
    @IBOutlet weak var workIntervalSlider: UISlider!

    @IBOutlet weak var maxThreadsTextField: UITextField!
    @IBOutlet weak var minThreadsTextField: UITextField!
    @IBOutlet weak var minWorkIntensityTextField: UITextField!
    @IBOutlet weak var maxWorkIntensityTextField: UITextField!

    let centralManager = CBCentralManager()
    let peripheralManager = CBPeripheralManager()

    override func viewDidLoad() {
        super.viewDidLoad()
        minWorkIntensityTextField.text = String(defaultLongestIntervalMicros)
        maxWorkIntensityTextField.text = String(1)
        minThreadsTextField.text = String(4)
        maxThreadsTextField.text = String(50)
        [maxThreadsTextField, minThreadsTextField, minWorkIntensityTextField, maxWorkIntensityTextField].forEach {
            $0?.delegate = self
        }
    }

    @IBAction func startBenchmark(_ sender: Any) {
        SentryBenchmarking.startBenchmark()
    }

    @IBAction func stopBenchmark(_ sender: Any) {
        let alert = UIAlertController(title: "Benchmark results", message: nil, preferredStyle: .alert)
        alert.addTextField { textField in
            textField.accessibilityIdentifier = "io.sentry.benchmark.value-marshaling-text-field"
        }
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: false)
        print("[iOS-Swift] benchmarking results:\n" + SentryBenchmarking.stopBenchmark()!.description)
    }

    var locationManager: CLLocationManager?
    @IBAction func startGPSUpdates(_ sender: Any) {
        defer { locationManager?.startUpdatingLocation() }
        guard locationManager == nil else { return }
        locationManager = CLLocationManager()
        locationManager?.delegate = self
    }

    @IBAction func endGPSUpdates(_ sender: Any) {
        locationManager?.stopUpdatingLocation()
        locationManager = nil
    }

    @IBAction func startHeadingUpdates(_ sender: Any) {
        defer { locationManager?.startUpdatingHeading() }
        guard locationManager == nil else { return }
        locationManager = CLLocationManager()
        locationManager?.delegate = self
    }

    @IBAction func endHeadingUpdates(_ sender: Any) {
        locationManager?.stopUpdatingHeading()
        locationManager = nil
    }

    var networkScanner: ProfilingNetworkScanner?
    @IBAction func startNetworkWork(_ sender: Any) {
        guard networkScanner == nil else { return }
        networkScanner = ProfilingNetworkScanner()
        networkScanner?.start()
    }

    @IBAction func endNetworkWork(_ sender: Any) {
        networkScanner?.end()
    }

    @IBAction func startBluetoothScan(_ sender: Any) {
        centralManager.scanForPeripherals(withServices: nil)
    }

    @IBAction func endBluetoothScan(_ sender: Any) {
        centralManager.stopScan()
    }

    @IBAction func startBluetoothAdvertise(_ sender: Any) {
        peripheralManager.startAdvertising([CBAdvertisementDataServiceUUIDsKey: [UUID(), UUID(), UUID()]])
    }

    @IBAction func endBluetoothAdvertise(_ sender: Any) {
        peripheralManager.stopAdvertising()
    }

    @IBAction func startCPUWork() {
        _adjustWorkThreadsToCurrentRequirement()
    }

    @IBAction func minWorkThreadCountChanged(_ sender: Any) {
        _adjustWorkThreadsToCurrentRequirement()
    }

    @IBAction func workThreadSliderChanged(_ sender: Any) {
        _adjustWorkThreadsToCurrentRequirement()
    }

    @IBAction func maxWorkThreadCountChanged(_ sender: Any) {
        _adjustWorkThreadsToCurrentRequirement()
    }

    @IBAction func endCPUWork() {
        cpuWorkthreads.forEach { $0.cancel() }
        cpuWorkthreads.removeAll()
    }

    @IBAction func minWorkIntervalChanged(_ sender: Any) {
        _adjustWorkIntervalToCurrentRequirements()
    }

    @IBAction func workIntensityChanged(_ sender: UISlider) {
        _adjustWorkIntervalToCurrentRequirements()
    }

    @IBAction func maxWorkIntervalChanged(_ sender: Any) {
        _adjustWorkIntervalToCurrentRequirements()
    }

    @IBAction func bgBrightnessChanged(_ sender: UISlider) {
        view.backgroundColor = .init(white: CGFloat(sender.value), alpha: 1)
    }

    // MARK: CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        print("locations: \(locations)")
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        print("headings: \(newHeading)")
    }

    // MARK: UITextFieldDelegate

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
    }

    // MARK: Private

    func _adjustWorkThreadsToCurrentRequirement() {
        let maxThreads = (maxThreadsTextField.text! as NSString).integerValue
        let minThreads = (minThreadsTextField.text! as NSString).integerValue
        let requiredThreads = _projectedRange(factor: workThreadSlider.value, min: minThreads, max: maxThreads)
        let diff = requiredThreads - cpuWorkthreads.count
        if diff == 0 {
            return
        } else if diff > 0 {
    //            print("creating \(diff) threads")
            for _ in 0 ..< diff {
                let thread = WorkThread()
                thread.qualityOfService = .userInteractive
                cpuWorkthreads.insert(thread)
                thread.start()
            }
        } else {
            let absDiff = abs(diff)
    //            print("removing \(absDiff) threads")
            for _ in 0 ..< absDiff {
                let thread = cpuWorkthreads.removeFirst()
                thread.cancel()
            }
        }
    }

    func _adjustWorkIntervalToCurrentRequirements() {
        let minInterval = (minWorkIntensityTextField.text! as NSString).integerValue
        let maxInterval = (maxWorkIntensityTextField.text! as NSString).integerValue
        workIntervalMicros = UInt32(_projectedRange(factor: workIntervalSlider.value, min: minInterval, max: maxInterval))
    //        print("workIntervalMicros: \(workIntervalMicros)")
    }
}
