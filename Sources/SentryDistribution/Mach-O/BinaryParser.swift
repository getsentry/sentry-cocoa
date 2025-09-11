import Darwin
import Foundation
import MachO

fileprivate let _dyld_get_image_uuid = unsafeBitCast(dlsym(dlopen(nil, RTLD_LAZY), "_dyld_get_image_uuid"), to: (@convention(c) (UnsafePointer<mach_header>, UnsafeRawPointer) -> Bool).self)

struct BinaryParser {
  //swiftlint:disable large_tuple
  private static func formatUUID(_ uuid: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)) -> String {
    "\(uuid.0.asHex)\(uuid.1.asHex)\(uuid.2.asHex)\(uuid.3.asHex)-\(uuid.4.asHex)\(uuid.5.asHex)-\(uuid.6.asHex)\(uuid.7.asHex)-\(uuid.8.asHex)\(uuid.9.asHex)-\(uuid.10.asHex)\(uuid.11.asHex)\(uuid.12.asHex)\(uuid.13.asHex)\(uuid.14.asHex)\(uuid.15.asHex)"
  }
  //swiftlint:enable large_tuple
  
  static func getMainBinaryUUID() -> String {
    guard let executableName = Bundle.main.infoDictionary?["CFBundleExecutable"] as? String else {
      fatalError("Executable name not found.")
    }
    let executablePath = "\(Bundle.main.bundlePath)/\(executableName)"
    
    for i in 0..<_dyld_image_count() {
      guard let header = _dyld_get_image_header(i) else { continue }
      let imagePath = String(cString: _dyld_get_image_name(i))
      
      guard imagePath == executablePath else {
        continue
      }

      var _uuid = UUID().uuid
      let _ = withUnsafeMutablePointer(to: &_uuid) {
        _dyld_get_image_uuid(header, $0)
      }
      return formatUUID(_uuid)
    }
    return ""
  }
}

private extension UInt8 {
  var asHex: String {
    String(format: "%02X", self)
  }
}
