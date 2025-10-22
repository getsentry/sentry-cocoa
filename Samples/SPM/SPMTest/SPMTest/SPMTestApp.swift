//
//  SPMTestApp.swift
//  SPMTest
//
//  Created by Noah Martin on 10/15/25.
//

import SentrySwift
import SwiftUI

@main
struct SPMTestApp: App {
  init() {
    let options = Options()
    options.enableAppHangTracking = true
    options.dsn = "testing"
    // This line will not compile, because `options` is defined in ObjC and `sessionReplay` is a type defined in
    // Swift.
    // options.sessionReplay.maskAllImages = false
    SentrySDK.start(options: options)
    let user = User()
    SentrySDK.setUser(user)
  }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
