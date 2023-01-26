import Foundation
import SwiftUI
import SentrySwiftUI

struct FormScreen : View {

    @State var name : String = ""

    func printMainThreda() {
        DispatchQueue.main.async {
            print("### IS MAIN THREAD")
        }
    }

    var body: some View {
        printMainThreda()
        return SentryTracedView("Form Screen") {
            List {
                Section{
                    HStack {
                        Text("Name")
                        TextField("name", text: $name)
                    }
                } footer: {
                    SentryTracedView("Text Span") {
                        Text("Name is required")
                            .opacity(name.isEmpty ? 1 : 0)
                    }
                }
            }.navigationTitle("Form Screen")
        }
    }
}

struct FormView_Previews: PreviewProvider {
    static var previews: some View {
        FormScreen()
    }
}
