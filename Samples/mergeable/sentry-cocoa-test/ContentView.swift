//
//  ContentView.swift
//  sentry-cocoa-test
//
//  Created by Denis Andrašec on 26.08.24.
//

import SwiftUI

struct ContentView: View {
    @StateObject var launchTracker: LaunchTracker
    
    init() {
        _launchTracker = StateObject(wrappedValue: LaunchTracker())
    }
    
    var body: some View {
        VStack {
            Text("Number of Launches: \(launchTracker.numberOfLaunches)")
            Text("Average Launch Time: \(String(format: "%.2f", launchTracker.averageLaunchTime)) seconds")
        }
        .padding()
        .onAppear {
            let launchTime = ProcessTimeManager.shared.time
            launchTracker.recordLaunch(launchTime: launchTime)
        }
    }
}

#Preview {
    ContentView()
}

class LaunchTracker: ObservableObject {
    @Published var numberOfLaunches: Int = 0
    @Published var averageLaunchTime: TimeInterval = 0.0
    
    private let numberOfLaunchesKey = "numberOfLaunches"
    private let cumulativeLaunchTimeKey = "cumulativeLaunchTime"
    
    init() {
        loadLaunchData()
    }
    
    func recordLaunch(launchTime: TimeInterval) {
        let defaults = UserDefaults.standard
        
        let previousNumberOfLaunches = defaults.integer(forKey: numberOfLaunchesKey)
        let previousCumulativeLaunchTime = defaults.double(forKey: cumulativeLaunchTimeKey)
        
        let newNumberOfLaunches = previousNumberOfLaunches + 1
        let newCumulativeLaunchTime = previousCumulativeLaunchTime + launchTime
        
        defaults.set(newNumberOfLaunches, forKey: numberOfLaunchesKey)
        defaults.set(newCumulativeLaunchTime, forKey: cumulativeLaunchTimeKey)
        
        // Update the published properties
        numberOfLaunches = newNumberOfLaunches
        averageLaunchTime = newCumulativeLaunchTime / Double(newNumberOfLaunches)
    }
    
    private func loadLaunchData() {
        let defaults = UserDefaults.standard
        
        numberOfLaunches = defaults.integer(forKey: numberOfLaunchesKey)
        let cumulativeLaunchTime = defaults.double(forKey: cumulativeLaunchTimeKey)
        
        if numberOfLaunches > 0 {
            averageLaunchTime = cumulativeLaunchTime / Double(numberOfLaunches)
        } else {
            averageLaunchTime = 0.0
        }
    }
}
