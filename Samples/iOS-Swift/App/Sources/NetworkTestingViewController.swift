import Foundation
import UIKit

class NetworkTestingViewController: UIViewController {
    
    // MARK: - UI Elements
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let stackView = UIStackView()
    
    private let titleLabel = UILabel()
    private let descriptionLabel = UILabel()
    
    // Request section
    private let requestSectionLabel = UILabel()
    private let requestUrlField = UITextField()
    private let bodyTypeLabel = UILabel()
    private let bodyTypeSegmentControl = UISegmentedControl(items: ["JSON", "Form", "Text", "Binary"])
    private let requestBodyTextView = UITextView()
    private let sendRequestButton = UIButton(type: .system)
    
    // Response section
    private let responseSectionLabel = UILabel()
    private let responseStatusLabel = UILabel()
    private let responseHeadersTextView = UITextView()
    private let responseBodyTextView = UITextView()
    
    // Activity indicator
    private let activityIndicator = UIActivityIndicatorView(style: .large)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupDefaults()
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "Network Testing"
        
        setupScrollView()
        setupStackView()
        setupRequestSection()
        setupQuickTests()
        setupResponseSection()
        setupActivityIndicator()
        setupDebugUISpacing()
    }
    
    private func setupDefaults() {
        requestUrlField.text = "https://httpbin.org/post"
        updateBodyTextViewForType(0) // JSON
    }
    
    @objc private func bodyTypeChanged() {
        updateBodyTextViewForType(bodyTypeSegmentControl.selectedSegmentIndex)
    }
    
    private func setupRequestBody(_ request: inout URLRequest) {
        let contentTypes = ["application/json", "application/x-www-form-urlencoded", "text/plain; charset=utf-8", "application/octet-stream"]
        let index = bodyTypeSegmentControl.selectedSegmentIndex
        
        if index == 3 { // Binary
            request.httpBody = Data(randomByteCount: 10_240)
        } else {
            request.httpBody = (requestBodyTextView.text ?? "").data(using: .utf8)
        }
        request.setValue(contentTypes.element(at: index) ?? "text/plain", forHTTPHeaderField: "Content-Type")
    }
    
    private func updateBodyTextViewForType(_ index: Int) {
        let bodies = [
            "{\"test\": \"network_capture\", \"timestamp\": \(Date().timeIntervalSince1970), \"source\": \"iOS-Swift-NetworkTesting\"}",
            "test=network_capture&source=iOS-Swift-NetworkTesting&timestamp=\(Int(Date().timeIntervalSince1970))",
            "This is a plain text body for testing network capture.\nLine 2 of the text.\nTimestamp: \(Date())",
            "// Binary data will be generated automatically\n// Size: ~10KB of random bytes"
        ]
        requestBodyTextView.text = bodies.element(at: index) ?? ""
        requestBodyTextView.isEditable = index != 3
    }
    
    @objc private func sendRequest() {
        guard let urlString = requestUrlField.text,
              !urlString.isEmpty,
              let url = URL(string: urlString) else {
            showAlert(title: "Invalid URL", message: "Please enter a valid URL")
            return
        }
        
        responseStatusLabel.text = "Status: Sending..."
        responseStatusLabel.textColor = .label
        responseHeadersTextView.text = ""
        responseBodyTextView.text = ""
        activityIndicator.startAnimating()
        sendRequestButton.isEnabled = false
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        setupRequestBody(&request)
        
        request.setValue("sentry-ios-test/1.0", forHTTPHeaderField: "User-Agent")
        request.setValue("network-test-\(UUID().uuidString)", forHTTPHeaderField: "X-Request-ID")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.handleResponse(data: data, response: response, error: error)
                self?.activityIndicator.stopAnimating()
                self?.sendRequestButton.isEnabled = true
            }
        }.resume()
    }
    
    private func handleResponse(data: Data?, response: URLResponse?, error: Error?) {
        if let error = error {
            responseStatusLabel.text = "Status: ❌ Error"
            responseStatusLabel.textColor = .systemRed
            responseBodyTextView.text = "Error: \(error.localizedDescription)"
            return
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            responseStatusLabel.text = "Status: ⚠️ Invalid Response"
            responseStatusLabel.textColor = .systemOrange
            return
        }
        
        let code = httpResponse.statusCode
        let emoji = (200..<300).contains(code) ? "✅" : "⚠️"
        responseStatusLabel.text = "Status: \(emoji) \(code) \(HTTPURLResponse.localizedString(forStatusCode: code))"
        responseStatusLabel.textColor = (200..<300).contains(code) ? .systemGreen : .systemOrange
        
        responseHeadersTextView.text = httpResponse.allHeaderFields
            .sorted { "\($0.key)" < "\($1.key)" }
            .map { "\($0.key): \($0.value)" }
            .joined(separator: "\n")
        
        guard let data = data else { return }
        
        if let json = try? JSONSerialization.jsonObject(with: data),
           let prettyData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
           let prettyString = String(data: prettyData, encoding: .utf8) {
            responseBodyTextView.text = prettyString
        } else if let bodyString = String(data: data, encoding: .utf8) {
            responseBodyTextView.text = bodyString
        } else {
            responseBodyTextView.text = "(Binary data, \(data.count) bytes)"
        }
    }
    
    @objc private func testJsonBody() { 
        performTest(bodyType: 0, customBody: """
        {"test": "json_body_test", "timestamp": \(Date().timeIntervalSince1970), "nested": {"key": "value", "array": [1, 2, 3]}}
        """)
    }
    
    @objc private func testFormBody() {
        performTest(bodyType: 1, customBody: "name=John+Doe&email=john%40example.com&test=form_body_test&timestamp=\(Int(Date().timeIntervalSince1970))")
    }
    
    @objc private func testTextBody() {
        performTest(bodyType: 2, customBody: "This is a plain text body test.\nTesting multiline text content.\nSpecial characters: !@#$%^&*()\nUnicode: 你好世界 🚀\nTimestamp: \(Date())")
    }
    
    @objc private func testBinaryBody() {
        performTest(bodyType: 3, customBody: "// Sending 10KB of random binary data")
        requestBodyTextView.isEditable = false
    }
    
    private func performTest(bodyType: Int, customBody: String? = nil) {
        requestUrlField.text = "https://httpbin.org/post"
        bodyTypeSegmentControl.selectedSegmentIndex = bodyType
        if let body = customBody {
            requestBodyTextView.text = body
        }
        sendRequest()
    }
    
    @objc private func testLargePayload() {
        let longStr = String(repeating: "Test string for truncation. ", count: 10)
        let items = (0..<200).map { ["index": $0, "id": UUID().uuidString, "data": longStr, "metadata": ["user": "user-\($0)", "details": longStr, "nested": ["data": longStr]]] }
        let payload = ["test": "large_payload", "items": items] as [String: Any]
        if let jsonData = try? JSONSerialization.data(withJSONObject: payload, options: .prettyPrinted), let json = String(data: jsonData, encoding: .utf8) {
            performTest(bodyType: 0, customBody: json)
        }
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UI Setup
extension NetworkTestingViewController {
    private func setupScrollView() {
        view.addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
        contentView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -100),
            
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
    }
    
    private func setupStackView() {
        contentView.addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.alignment = .fill
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -40)
        ])
        
        titleLabel.text = "Network Request Tester"
        titleLabel.font = .systemFont(ofSize: 24, weight: .bold)
        descriptionLabel.text = "Test HTTP requests and inspect Sentry's network capture"
        descriptionLabel.numberOfLines = 0
        descriptionLabel.font = .systemFont(ofSize: 14)
        descriptionLabel.textColor = .secondaryLabel
        
        [titleLabel, descriptionLabel].forEach { stackView.addArrangedSubview($0) }
    }
    
    private func setupRequestSection() {
        requestSectionLabel.text = "Request Configuration"
        requestSectionLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        stackView.addArrangedSubview(requestSectionLabel)
        
        requestUrlField.placeholder = "Enter URL (e.g., https://httpbin.org/post)"
        requestUrlField.borderStyle = .roundedRect
        requestUrlField.autocapitalizationType = .none
        requestUrlField.autocorrectionType = .no
        requestUrlField.keyboardType = .URL
        stackView.addArrangedSubview(requestUrlField)
        
        bodyTypeLabel.text = "Body Type:"
        bodyTypeLabel.font = .systemFont(ofSize: 14, weight: .medium)
        stackView.addArrangedSubview(bodyTypeLabel)
        
        bodyTypeSegmentControl.selectedSegmentIndex = 0 // JSON
        bodyTypeSegmentControl.addTarget(self, action: #selector(bodyTypeChanged), for: .valueChanged)
        stackView.addArrangedSubview(bodyTypeSegmentControl)
        
        let bodyLabel = UILabel()
        bodyLabel.text = "Request Body:"
        bodyLabel.font = .systemFont(ofSize: 14, weight: .medium)
        stackView.addArrangedSubview(bodyLabel)
        
        configureTextView(requestBodyTextView, height: 120)
        stackView.addArrangedSubview(requestBodyTextView)
        
        sendRequestButton.setTitle("Send Request", for: .normal)
        sendRequestButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        sendRequestButton.backgroundColor = .systemBlue
        sendRequestButton.setTitleColor(.white, for: .normal)
        sendRequestButton.layer.cornerRadius = 8
        sendRequestButton.addTarget(self, action: #selector(sendRequest), for: .touchUpInside)
        sendRequestButton.translatesAutoresizingMaskIntoConstraints = false
        sendRequestButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
        stackView.addArrangedSubview(sendRequestButton)
    }
    
    private func setupQuickTests() {
        let label = UILabel()
        label.text = "Quick Tests:"
        label.font = .systemFont(ofSize: 14, weight: .medium)
        stackView.addArrangedSubview(label)
        
        let buttons1 = [("JSON Body", #selector(testJsonBody)), ("Form Body", #selector(testFormBody)), ("Text Body", #selector(testTextBody))]
        let stack1 = createButtonStack(buttons: buttons1)
        stackView.addArrangedSubview(stack1)
        
        let buttons2 = [("Binary Body", #selector(testBinaryBody)), ("Large Payload", #selector(testLargePayload))]
        let stack2 = createButtonStack(buttons: buttons2)
        stack2.addArrangedSubview(UIView()) // Empty spacer
        stackView.addArrangedSubview(stack2)
    }
    
    private func createButtonStack(buttons: [(String, Selector)]) -> UIStackView {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 10
        stack.distribution = .fillEqually
        buttons.forEach { stack.addArrangedSubview(createQuickTestButton(title: $0.0, action: $0.1)) }
        return stack
    }
    
    private func setupResponseSection() {
        responseSectionLabel.text = "Response"
        responseSectionLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        stackView.addArrangedSubview(responseSectionLabel)
        
        responseStatusLabel.text = "Status: Not sent yet"
        responseStatusLabel.font = .systemFont(ofSize: 14, weight: .medium)
        stackView.addArrangedSubview(responseStatusLabel)
        
        let headersLabel = UILabel()
        headersLabel.text = "Response Headers:"
        headersLabel.font = .systemFont(ofSize: 14, weight: .medium)
        stackView.addArrangedSubview(headersLabel)
        
        configureTextView(responseHeadersTextView, height: 100, editable: false)
        stackView.addArrangedSubview(responseHeadersTextView)
        
        let bodyLabel = UILabel()
        bodyLabel.text = "Response Body:"
        bodyLabel.font = .systemFont(ofSize: 14, weight: .medium)
        stackView.addArrangedSubview(bodyLabel)
        
        configureTextView(responseBodyTextView, height: 200, editable: false)
        stackView.addArrangedSubview(responseBodyTextView)
    }
    
    private func setupActivityIndicator() {
        activityIndicator.hidesWhenStopped = true
        view.addSubview(activityIndicator)
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    private func setupDebugUISpacing() {
        let separatorView = UIView()
        separatorView.backgroundColor = .separator
        let debugLabel = UILabel()
        debugLabel.text = "Debug UI Space Below"
        debugLabel.font = .systemFont(ofSize: 10)
        debugLabel.textColor = .tertiaryLabel
        debugLabel.textAlignment = .center
        
        [separatorView, debugLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }
        
        NSLayoutConstraint.activate([
            separatorView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            separatorView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            separatorView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -98),
            separatorView.heightAnchor.constraint(equalToConstant: 0.5),
            debugLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            debugLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -80)
        ])
    }
    
    private func configureTextView(_ textView: UITextView, height: CGFloat, editable: Bool = true) {
        textView.layer.borderColor = UIColor.separator.cgColor
        textView.layer.borderWidth = 1
        textView.layer.cornerRadius = 8
        textView.font = .monospacedSystemFont(ofSize: editable ? 12 : 11, weight: .regular)
        textView.isEditable = editable
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.heightAnchor.constraint(equalToConstant: height).isActive = true
    }
    
    private func createQuickTestButton(title: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 14)
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.systemBlue.cgColor
        button.layer.cornerRadius = 6
        button.addTarget(self, action: action, for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(equalToConstant: 36).isActive = true
        return button
    }
}
