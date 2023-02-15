import Foundation
import SentrySwiftUI
import SwiftUI

struct FormScreen: View {

    @State var name: String = ""
    @State var email: String = ""

    func getCurrentTracer() -> String? {
        return SentryPerformanceTracker.shared.activeSpanId()?.sentrySpanIdString
    }
    
    var body: some View {
        SentryTracedView("Form Screen") {
            List {
                Section {
                    HStack {
                        Text("Name")
                        TextField("name", text: $name)
                    }
                } header: {
                    Text(getCurrentTracer() ?? "NO SPAN")
                        .accessibilityIdentifier("SPAN_ID")
                } footer: {
                    SentryTracedView("Text Span") {
                        Text("Name is required")
                            .opacity(name.isEmpty ? 1 : 0)
                    }
                }

                Section {
                    EmailView(email: $email)
                }
            }.navigationTitle("Form Screen")
                .toolbar {
                    Button {
                        name = "John"
                        email = "John@email.com"
                    } label: {
                        Text("Test")
                    }
                }
        }
    }
}

struct EmailView: View {

    @Binding var email: String

    private func emailIsValid( _ email: String) -> Bool {
        return email.contains("@") || email.isEmpty
    }

    var body: some View {
        SentryTracedView("Second View") {
            HStack {
                Text("E-mail")
                TextField("E-Mail", text: $email)
                    .keyboardType(.emailAddress)
                    .border(emailIsValid(email) ? .clear : .red)
            }
        }
    }
}

struct FormView_Previews: PreviewProvider {
    static var previews: some View {
        FormScreen()
    }
}
