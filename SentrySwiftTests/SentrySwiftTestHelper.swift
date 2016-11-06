//
//  SentrySwiftTestHelper.swift
//  SentrySwift
//
//  Created by Daniel Griesser on 05/11/16.
//
//

import Foundation

class SentrySwiftTestHelper {
    
    typealias JSONCrashFile = [String: AnyObject]
    
    private func getJSONCrashFileFromPath(path: String) -> JSONCrashFile? {
        #if swift(>=3.0)
            do {
                let data = try NSData(contentsOf: NSURL(fileURLWithPath: path) as URL, options: NSData.ReadingOptions.mappedIfSafe)
                let json = try JSONSerialization.jsonObject(with: data as Data, options: JSONSerialization.ReadingOptions())
                return json as? JSONCrashFile
            } catch {
                return nil
            }
        #else
            do {
                let data = try NSData(contentsOfURL: NSURL(fileURLWithPath: path), options: NSDataReadingOptions.DataReadingMappedIfSafe)
                let json = try NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions())
                return json as? JSONCrashFile
            } catch {
                return nil
            }
        #endif
    }
    
    #if !swift(>=3.0)
    func readIOSJSONCrashFile(name name: String) -> JSONCrashFile? {
        let bundle = NSBundle(forClass: self.dynamicType)
        guard let path = bundle.pathForResource(name, ofType: "json", inDirectory: "crashReports/ios-simulator-debug/") else {
            return nil
        }
        return getJSONCrashFileFromPath(path)
    }
    #endif
    
    #if swift(>=3.0)
    func readIOSJSONCrashFile(name: String) -> JSONCrashFile? {
        let bundle = Bundle(for: type(of: self))
        guard let path = bundle.path(forResource: name, ofType: "json", inDirectory: "crashReports/ios-simulator-debug/") else {
            return nil
        }
        return getJSONCrashFileFromPath(path: path)
    }
    #endif
    
    #if swift(>=3.0)
    func readJSONCrashFile(name: String) -> JSONCrashFile? {
        let bundle = Bundle(for: type(of: self))
        guard let path = bundle.path(forResource: name, ofType: "json") else {
            return nil
        }
        return getJSONCrashFileFromPath(path: path)
    }
    #endif
    
    #if !swift(>=3.0)
    func readJSONCrashFile(name name: String) -> JSONCrashFile? {
        let bundle = NSBundle(forClass: self.dynamicType)
        guard let path = bundle.pathForResource(name, ofType: "json") else {
            return nil
        }
        return getJSONCrashFileFromPath(path)
    }
    #endif
    
}
