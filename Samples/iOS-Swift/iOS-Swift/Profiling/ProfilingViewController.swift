import UIKit

class ProfilingViewController: UIViewController, UITextFieldDelegate {
    
    @IBOutlet weak var workThreadLabel: UILabel!
    @IBOutlet weak var workIntensityFactorLabel: UILabel!
    
    @IBOutlet weak var workThreadSlider: UISlider!
    @IBOutlet weak var workIntervalSlider: UISlider!
    
    @IBOutlet weak var maxThreadsTextField: UITextField!
    @IBOutlet weak var minThreadsTextField: UITextField!
    @IBOutlet weak var minWorkIntensityTextField: UITextField!
    @IBOutlet weak var maxWorkIntensityTextField: UITextField!
    @IBOutlet weak var valueTextField: UITextField!
    
    @IBOutlet weak var launchProfilingMarkerFileCheckButton: UIButton!
    @IBOutlet weak var profilingUITestDataMarshalingTextField: UITextField!
    @IBOutlet weak var profilingUITestDataMarshalingStatus: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        minWorkIntensityTextField.text = String(defaultLongestIntervalMicros)
        maxWorkIntensityTextField.text = String(1)
        minThreadsTextField.text = String(4)
        maxThreadsTextField.text = String(50)
        [maxThreadsTextField, minThreadsTextField, minWorkIntensityTextField, maxWorkIntensityTextField].forEach {
            $0?.delegate = self
        }
        profilingUITestDataMarshalingTextField.accessibilityLabel = "io.sentry.ui-tests.profile-marshaling-text-field"
        launchProfilingMarkerFileCheckButton.accessibilityLabel = "io.sentry.ui-tests.app-launch-profile-marker-file-button"
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        SentrySDK.reportFullyDisplayed()
    }
    
    @IBAction func startBenchmark(_ sender: UIButton) {
        highlightButton(sender)
        SentryBenchmarking.startBenchmark()
    }
    
    @IBAction func stopBenchmark(_ sender: UIButton) {
        highlightButton(sender)
        let value = SentryBenchmarking.stopBenchmark()!
        valueTextField.isHidden = false
        valueTextField.text = value
        print("[iOS-Swift] [Profiling] benchmarking results:\n\(value)")
    }
    
    @IBAction func startCPUWork(_ sender: UIButton) {
        highlightButton(sender)
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
    
    @IBAction func endCPUWork(_ sender: UIButton) {
        highlightButton(sender)
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
    
    @IBAction func checkLaunchProfilingMarkerFile(_ sender: Any) {
        let launchProfileMarkerPath = ((NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true).first! as NSString).appendingPathComponent("io.sentry") as NSString).appendingPathComponent("profileLaunch")
        if FileManager.default.fileExists(atPath: launchProfileMarkerPath) {
            profilingUITestDataMarshalingTextField.text = "<exists>"
        } else {
            profilingUITestDataMarshalingTextField.text = "<missing>"
        }
    }
    
    @IBAction func viewLastProfile(_ sender: Any) {
        profilingUITestDataMarshalingTextField.text = "<fetching...>"
        withProfile(fileName: "profile") { file in
            handleContents(file: file)
        }
    }
    
    @IBAction func viewLaunchProfile(_ sender: Any) {
        profilingUITestDataMarshalingTextField.text = "<fetching...>"
        withProfile(fileName: "launchProfile") { file in
            handleContents(file: file)
        }
    }
        
    // MARK: UITextFieldDelegate
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
    }
}

// MARK: Private
extension ProfilingViewController {
    func withProfile(fileName: String, block: (URL?) -> Void) {
        let appSupportDirectory = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true).first!
        guard let url = URL(string: appSupportDirectory) else {
            block(nil)
            return
        }
        for file in FileManager.default.enumerator(at: url, includingPropertiesForKeys: [URLResourceKey.nameKey])! {
            let url = file as! URL
            if url.absoluteString.contains(fileName) {
                block(url)
                return
            }
        }
        block(nil)
    }
    
    func handleContents(file: URL?) {
        guard let file = file else {
            profilingUITestDataMarshalingTextField.text = "<missing>"
            profilingUITestDataMarshalingStatus.text = "❌"
            return
        }
        guard let data = try? Data(contentsOf: file) else {
            profilingUITestDataMarshalingTextField.text = "<empty>"
            profilingUITestDataMarshalingStatus.text = "❌"
            return
        }
        let contents = data.base64EncodedString()
        print("[iOS-Swift] [Profiling] contents of file at \(file): \(String(data: data, encoding: .utf8))")
        profilingUITestDataMarshalingTextField.text = contents
        profilingUITestDataMarshalingStatus.text = "✅"
    }
    
    func _adjustWorkThreadsToCurrentRequirement() {
        let maxThreads = (maxThreadsTextField.text! as NSString).integerValue
        let minThreads = (minThreadsTextField.text! as NSString).integerValue
        let requiredThreads = _projectedRange(factor: workThreadSlider.value, min: minThreads, max: maxThreads)
        let diff = requiredThreads - cpuWorkthreads.count
        if diff == 0 {
            return
        } else if diff > 0 {
            for _ in 0 ..< diff {
                let thread = WorkThread()
                thread.qualityOfService = .userInteractive
                cpuWorkthreads.insert(thread)
                thread.start()
            }
        } else {
            let absDiff = abs(diff)
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
    }
}
