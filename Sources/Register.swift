//
//  Register.swift
//  SentrySwift
//
//  Created by Daniel Griesser on 24/01/2017.
//
//

import Foundation

@objc(SentryRegister) public final class Register: NSObject {
    public var registers: [String: [String: String]] = [:]
    
    @objc public init?(registerDict: [String: AnyObject]?) {
        guard let registerDict = registerDict else { return nil }
        for (registerKey, registerValues) in registerDict {
            if let registerValues = registerValues as? [String: AnyObject] {
                registers[registerKey] = [:]
                for (key, value) in registerValues {
                    if let memoryAddress = MemoryAddress(value)?.asHex() {
                        registers[registerKey]?[key] = memoryAddress
                    }
                }
            }
        }
    }
    
}
