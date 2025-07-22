import FileProvider
import SentrySampleShared
import UniformTypeIdentifiers

class FileProviderExtension: NSFileProviderExtension {
    
    override init() {
        super.init()
        SentrySDKWrapper.shared.startSentry()
    }
    
    override func item(for identifier: NSFileProviderItemIdentifier) throws -> NSFileProviderItem {
        // Mock file items for demonstration
        if identifier == .rootContainer {
            return FileProviderItem(
                identifier: identifier,
                filename: "Sentry Files",
                typeIdentifier: UTType.folder.identifier
            )
        } else if identifier.rawValue == "sentry-logs" {
            return FileProviderItem(
                identifier: identifier,
                filename: "sentry-debug.log",
                typeIdentifier: UTType.plainText.identifier,
                documentSize: 1_024
            )
        } else if identifier.rawValue == "sentry-config" {
            return FileProviderItem(
                identifier: identifier,
                filename: "sentry-config.json",
                typeIdentifier: UTType.json.identifier,
                documentSize: 512
            )
        }
        
        // If item not found, capture error and throw
        let error = NSFileProviderError(.noSuchItem)
        throw error
    }
    
    override func urlForItem(withPersistentIdentifier identifier: NSFileProviderItemIdentifier) -> URL? {
        guard let item = try? self.item(for: identifier) else {
            return nil
        }
        
        // Generate temporary URL for the file
        let tempURL = temporaryDirectoryURL.appendingPathComponent(item.filename)
        return tempURL
    }
    
    override func persistentIdentifierForItem(at url: URL) -> NSFileProviderItemIdentifier? {
        // Map URLs back to identifiers
        let filename = url.lastPathComponent
        let identifier: NSFileProviderItemIdentifier
        
        switch filename {
        case "sentry-debug.log":
            identifier = NSFileProviderItemIdentifier("sentry-logs")
        case "sentry-config.json":
            identifier = NSFileProviderItemIdentifier("sentry-config")
        default:
            return nil
        }

        return identifier
    }
    
    override func enumerator(for containerItemIdentifier: NSFileProviderItemIdentifier) throws -> NSFileProviderEnumerator {
        return FileProviderEnumerator(enumeratedItemIdentifier: containerItemIdentifier)
    }
    
    override func startProvidingItem(at url: URL, completionHandler: @escaping (Error?) -> Void) {
        // Start transaction for file provision
        let filename = url.lastPathComponent
        
        // Simulate file generation based on filename
        DispatchQueue.global(qos: .utility).async {
            do {
                let content: String
                switch filename {
                case "sentry-debug.log":
                    content = self.generateMockLogContent()
                case "sentry-config.json":
                    content = self.generateMockConfigContent()
                default:
                    content = "Sentry File Provider - Unknown file type"
                }
                
                try content.write(to: url, atomically: true, encoding: .utf8)

                completionHandler(nil)
            } catch {
                completionHandler(error)
            }
        }
    }
    
    override func stopProvidingItem(at url: URL) {
        // Clean up the file
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            // handle
        }
    }
    
    // MARK: - Private Methods
    
    private func generateMockLogContent() -> String {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        return """
        [Sentry File Provider Debug Log]
        Generated: \(timestamp)
        
        [INFO] File Provider extension initialized
        [DEBUG] Sentry SDK configured for file provider
        [INFO] Ready to provide files to system
        [DEBUG] Mock log entry for demonstration
        [INFO] File access monitoring active
        """
    }
    
    private func generateMockConfigContent() -> String {
        return """
        {
          "file_provider": {
            "name": "Sentry File Provider",
            "version": "1.0.0",
            "supported_types": ["log", "json", "txt"],
            "max_file_size": 10485760,
            "features": {
              "enumeration": true,
              "uploading": false,
              "downloading": true
            }
          },
          "sentry": {
            "enabled": true,
            "environment": "sample-file-provider",
            "debug": true
          }
        }
        """
    }
    
    private var temporaryDirectoryURL: URL {
        return FileManager.default.temporaryDirectory.appendingPathComponent("SentryFileProvider")
    }
} 
