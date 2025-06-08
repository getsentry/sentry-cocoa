import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Text("Welcome to MultiPlatformSampleApp")
                .font(.largeTitle)
                .padding()
            Text("This is a shared SwiftUI view for all platforms.")
                .font(.subheadline)
                .padding()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
} 
