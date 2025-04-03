import Sentry
import UIKit

class ProfilingViewController: UIViewController, UITextFieldDelegate {
    @IBOutlet weak var launchProfilingMarkerFileCheckButton: UIButton!
    @IBOutlet weak var profilingUITestDataMarshalingTextField: UITextField!
    @IBOutlet weak var profilingUITestDataMarshalingStatus: UILabel!
        
    @IBOutlet weak var sampleRateField: UITextField!
    @IBOutlet weak var samplerSwitch: UISwitch!
    @IBOutlet weak var samplerValueField: UILabel!

    @IBOutlet weak var profilingV2Switch: UISwitch!
    @IBOutlet weak var profilingV2Stack: UIStackView!

    @IBOutlet weak var dsnView: UIView!

    override func viewDidLoad() {
        super.viewDidLoad()
        profilingUITestDataMarshalingTextField.accessibilityLabel = "io.sentry.ui-tests.profile-marshaling-text-field"
        launchProfilingMarkerFileCheckButton.accessibilityLabel = "io.sentry.ui-tests.app-launch-profile-marker-file-button"
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        SentrySDK.reportFullyDisplayed()
        
        addDSNDisplay(self, vcview: dsnView)

        guard let options = SentrySDK.currentHub().getClient()?.options else { return }

        if let sampleRate = options.profilesSampleRate {
            sampleRateField.text = String(format: "%.2f", sampleRate.floatValue)
        } else {
            sampleRateField.text = "nil"
        }

        samplerSwitch.isOn = options.profilesSampler != nil
        if options.profilesSampler != nil {
            if let samplerValue = SentrySDKTestConfiguration.Profiling.getSamplerValue() {
                samplerValueField.text = String(format: "%.2f", samplerValue)
            } else {
                samplerValueField.text = "dynamic"
            }
        }

        profilingV2Switch.isOn = options.configureProfiling != nil
    }

    @IBAction func checkLaunchProfilingMarkerFile(_ sender: Any) {
        let launchProfileMarkerPath = ((NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first! as NSString).appendingPathComponent("io.sentry") as NSString).appendingPathComponent("profileLaunch")
        if FileManager.default.fileExists(atPath: launchProfileMarkerPath) {
            profilingUITestDataMarshalingTextField.text = "<exists>"
        } else {
            profilingUITestDataMarshalingTextField.text = "<missing>"
        }
    }
    
    @IBAction func startContinuousProfiler(_ sender: Any) {
        SentrySDK.startProfiler()
    }
    
    @IBAction func stopContinuousProfiler(_ sender: Any) {
        SentrySDK.stopProfiler()
    }
    
    @IBAction func viewLastProfile(_ sender: Any) {
        profilingUITestDataMarshalingTextField.text = "<fetching...>"
        withProfile(continuous: false) { file in
            handleContents(file: file)
        }
    }
    
    @IBAction func viewFirstContinuousProfileChunk(_ sender: Any) {
        profilingUITestDataMarshalingTextField.text = "<fetching...>"
        withProfile(continuous: true) { file in
            handleContents(file: file)
        }
    }

    @IBAction func sampleRateEdited(_ sender: UITextField) {
        guard let text = sender.text, !text.isEmpty else {
            UserDefaults.standard.removeObject(forKey: SentrySDKTestConfiguration.Profiling.Key.sampleRate.rawValue)
            return
        }

        let rate = (text as NSString).floatValue
        UserDefaults.standard.set(rate, forKey: SentrySDKTestConfiguration.Profiling.Key.sampleRate.rawValue)
    }

    @IBAction func samplerSwitchToggled(_ sender: UISwitch) {
        if sender.isOn {
            if let text = samplerValueField.text {
                let rate = (text as NSString).floatValue
                UserDefaults.standard.set(rate, forKey: SentrySDKTestConfiguration.Profiling.Key.samplerValue.rawValue)
                samplerValueField.text = String(format: "%.2f", rate)
            }
        } else {
            UserDefaults.standard.removeObject(forKey: SentrySDKTestConfiguration.Profiling.Key.samplerValue.rawValue)
        }
    }
    
    @IBAction func samplerValueEdited(_ sender: UITextField) {
        if let text = sender.text {
            let rate = (text as NSString).floatValue
            UserDefaults.standard.set(rate, forKey: SentrySDKTestConfiguration.Profiling.Key.samplerValue.rawValue)
        }
    }

    // MARK: UITextFieldDelegate
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
    }
    
    private func withProfile(continuous: Bool, block: (URL?) -> Void) {
        let cachesDirectory = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first!
        let fm = FileManager.default
        let dir = "\(cachesDirectory)/io.sentry/" + (continuous ? "continuous-profiles" : "trace-profiles")
        let count = try! fm.contentsOfDirectory(atPath: dir).count
        //swiftlint:disable empty_count
        guard continuous || count > 0 else {
            //swiftlint:enable empty_count
            profilingUITestDataMarshalingTextField.text = "<missing>"
            return
        }
        let fileName = "profile\(continuous ? 0 : count - 1)"
        let fullPath = "\(dir)/\(fileName)"
        
        if fm.fileExists(atPath: fullPath) {
            let url = NSURL.fileURL(withPath: fullPath)
            block(url)
            do {
                try fm.removeItem(atPath: fullPath)
            } catch {
                SentrySDK.capture(error: error)
            }
            return
        }
        
        block(nil)
    }
    
    private func handleContents(file: URL?) {
        guard let file = file else {
            profilingUITestDataMarshalingTextField.text = "<missing>"
            profilingUITestDataMarshalingStatus.text = "❌"
            return
        }
        
        do {
            let data = try Data(contentsOf: file)
            let contents = data.base64EncodedString()
            print("[iOS-Swift] [debug] [ProfilingViewController] contents of file at \(file): \(String(describing: String(data: data, encoding: .utf8)))")
            profilingUITestDataMarshalingTextField.text = contents
            profilingUITestDataMarshalingStatus.text = "✅"
        } catch {
            SentrySDK.capture(error: error)
            profilingUITestDataMarshalingTextField.text = "<empty>"
            profilingUITestDataMarshalingStatus.text = "❌"
        }
    }
}
