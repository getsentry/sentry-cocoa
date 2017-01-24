//
//  Register.swift
//  SentrySwift
//
//  Created by Daniel Griesser on 24/01/2017.
//
//

import Foundation

@objc(SentryRegister) public final class Register: NSObject {
    public var register: [String: [String: String]] = [:]
    
    @objc public init?(registerDict: [String: AnyObject]?) {
        guard let registerDict = registerDict else {
            return
        }
        for (registerKey, registerValues) in registerDict {
            if let registerValues = registerValues as? [String: Int] {
                self.register[registerKey] = [:]
                for (key, value) in registerValues {
                    self.register[registerKey]?[key] = "\(value)"
                }
            }
        }
        print("\(self.register)")
    }
    
}

//extension Register: EventSerializable {
//    internal typealias SerializedType = SerializedTypeDictionary
//    
//    internal var serialized: SerializedType {
//        var attributes: [Attribute] = []
//        
//        attributes.append(("filename", fileName))
//        attributes.append(("function", function))
//        attributes.append(("module", module))
//        attributes.append(("lineno", line))
//        attributes.append(("colno", column))
//        attributes.append(("package", package))
//        attributes.append(("image_addr", imageAddress))
//        attributes.append(("instruction_addr", instructionAddress))
//        attributes.append(("symbol_addr", symbolAddress))
//        attributes.append(("platform", platform))
//        
//        return convertAttributes(attributes)
//    }
//}
