import SwiftUI

struct ContentView: View {
  var body: some View {
    VStack(spacing: 20.0) {
      Button("Check For Update Swift") {
        UpdateUtil.checkForUpdates()
      }
      .padding()
      .background(.blue)
      .foregroundColor(.white)
      .cornerRadius(10)
    }
    .padding()
  }
}

#Preview {
  ContentView()
}
