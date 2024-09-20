import SentrySwiftUI
import SwiftUI

struct SwiftUIView: View {
    @State var sliderValue: Double = 0
    
    var body: some View {
        SentryTracedView("SwiftUI View") {
            VStack {
                Text("Welcome \(sliderValue)")
                    .background(Color.green)
                    .replayRedact()
                Text("SwiftUI!")
            }
        }
    }
}

struct SwiftUIView_Previews: PreviewProvider {
    static var previews: some View {
        SwiftUIView()
    }
}
