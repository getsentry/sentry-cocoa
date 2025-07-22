import FileProvider
import UniformTypeIdentifiers

class FileProviderItem: NSObject, NSFileProviderItem {
    
    private let identifier: NSFileProviderItemIdentifier
    internal let filename: String
    internal let typeIdentifier: String
    private let documentSize: Int?
    internal let creationDate: Date?
    private let modificationDate: Date
    
    init(identifier: NSFileProviderItemIdentifier, 
         filename: String, 
         typeIdentifier: String,
         documentSize: Int? = nil) {
        self.identifier = identifier
        self.filename = filename
        self.typeIdentifier = typeIdentifier
        self.documentSize = documentSize
        self.creationDate = Date()
        self.modificationDate = Date()
        super.init()
    }
    
    // MARK: - NSFileProviderItem Protocol
    
    var itemIdentifier: NSFileProviderItemIdentifier {
        return identifier
    }
    
    var parentItemIdentifier: NSFileProviderItemIdentifier {
        return .rootContainer
    }
    
    var capabilities: NSFileProviderItemCapabilities {
        if typeIdentifier == UTType.folder.identifier {
            return [.allowsReading, .allowsContentEnumerating]
        } else {
            return [.allowsReading]
        }
    }
    
    var itemVersion: NSFileProviderItemVersion {
        return NSFileProviderItemVersion(
            contentVersion: modificationDate.timeIntervalSince1970.description.data(using: .utf8)!,
            metadataVersion: modificationDate.timeIntervalSince1970.description.data(using: .utf8)!
        )
    }

    var contentType: UTType {
        return UTType(self.typeIdentifier) ?? .data
    }
    
    var contentModificationDate: Date? {
        return self.modificationDate
    }
    
    var isDownloaded: Bool {
        return true // Our mock files are always "downloaded"
    }
    
    var isDownloading: Bool {
        return false
    }
    
    var downloadingError: Error? {
        return nil
    }
    
    var isUploaded: Bool {
        return true // Our mock files are always "uploaded"
    }
    
    var isUploading: Bool {
        return false
    }
    
    var uploadingError: Error? {
        return nil
    }
} 
