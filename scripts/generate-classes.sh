#!/bin/bash
set -euo pipefail

# Generates classes useful for testing of the performance of swizzling ViewControllers
# with plenty of code and view controllers.
# You can move the generated classes to a sample project and use the profiler to analyze
# how long the swizzling takes.

viewControllers="ViewControllers.swift"
dsnStorage="DSNStorage.swift"

if [ -f "$viewControllers" ] ; then
    rm "$viewControllers"
fi

if [ -f "$dsnStorage" ] ; then
    rm "$dsnStorage"
fi

for i in {1..1000}
do
   echo "class ViewController$i: UIViewController {
       override func viewDidLoad() {
        super.viewDidLoad()
       } 

       func a$i() -> Bool {
           return true
       }
    }" >> $viewControllers
done

for i in {1..2000}
do
   echo "class DSNStorage$i {
    
    static let shared = DSNStorage$i()
    
    private let dsnFile: URL
    
    private init() {
        // swiftlint:disable force_unwrapping
        let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        // swiftlint:enable force_unwrapping
        dsnFile = cachesDirectory.appendingPathComponent(\"dsn\")
    }
    
    func saveDSN$i(dsn: String) {
        do {
            deleteDSN$i()
            try dsn.write(to: dsnFile, atomically: true, encoding: .utf8)
        } catch {
            SentrySDK.capture(error: error)
        }
    }
    
    func getDSN$i() -> String? {
        let fileManager = FileManager.default
        do {
            if fileManager.fileExists(atPath: dsnFile.path) {
                return try String(contentsOfFile: dsnFile.path)
            }
        } catch {
            SentrySDK.capture(error: error)
        }
        
        return nil
    }
    
    func deleteDSN$i() {
        let fileManager = FileManager.default
        do {
            
            if fileManager.fileExists(atPath: dsnFile.path) {
                try fileManager.removeItem(at: dsnFile)
            }
        } catch {
            SentrySDK.capture(error: error)
        }
    }
    }" >> $dsnStorage
done

 