import Darwin
import Foundation
import MachO

typealias GetUUIDFuncType = (@convention(c) (UnsafePointer<mach_header>, UnsafeRawPointer) -> Bool)
fileprivate let _dyld_get_image_uuid = unsafeBitCast(dlsym(dlopen(nil, RTLD_LAZY), "_dyld_get_image_uuid"), to: GetUUIDFuncType.self)

enum BinaryParser {
  
  static func getMainBinaryUUID(getUUID: GetUUIDFuncType = _dyld_get_image_uuid) -> String? {
    guard let executableName = Bundle.main.infoDictionary?["CFBundleExecutable"] as? String else {
      return nil
    }
    let executablePath = "\(Bundle.main.bundlePath)/\(executableName)"
    
    for i in 0..<_dyld_image_count() {
      guard let header = _dyld_get_image_header(i) else { continue }
      let imagePath = String(cString: _dyld_get_image_name(i))
      
      guard imagePath == executablePath else {
        continue
      }

      var _uuid: uuid_t = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
      let _ = withUnsafeMutablePointer(to: &_uuid) {
        getUUID(header, $0)
      }
      return UUID(uuid: _uuid).uuidString
    }
    return nil
  }
}
