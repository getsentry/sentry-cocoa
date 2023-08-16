import Sentry
import SwiftUI

@available(watchOSApplicationExtension 7.0, *)
struct ContentView: View {
    
    @StateObject var viewModel = ContentViewModel()
    
    var addBreadcrumbAction: () -> Void = {
        let crumb = Breadcrumb(level: SentryLevel.info, category: "Debug")
        crumb.message = "tapped addBreadcrumb"
        crumb.type = "user"
        SentrySDK.addBreadcrumb(crumb)
    }
    
    var captureMessageAction: () -> Void = {
        SentrySDK.capture(message: "Yeah captured a message")
    }
    
    var captureErrorAction: () -> Void = {
        let error = NSError(domain: "SampleErrorDomain", code: 1, userInfo: [NSLocalizedDescriptionKey: "Object does not exist"])
        SentrySDK.capture(error: error) { (scope) in
            scope.setTag(value: "value", key: "myTag")
        }
    }
    
    var captureNSExceptionAction: () -> Void = {
        let exception = NSException(name: NSExceptionName("My Custom exeption"), reason: "User clicked the button", userInfo: nil)
        let scope = Scope()
        scope.setLevel(.fatal)
        SentrySDK.capture(exception: exception, scope: scope)
    }
    
    var captureTransaction: () -> Void = {
        let transaction = SentrySDK.startTransaction(name: "Some Transaction", operation: "some operation")
        DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 0.4...0.6), execute: {
            transaction.finish()
        })
    }
    
    var body: some View {
        ScrollView {
            VStack {
                Button(action: addBreadcrumbAction) {
                    Text("Add Breadcrumb")
                }
                
                Button(action: captureMessageAction) {
                    Text("Capture Message")
                }
                
                Button(action: captureErrorAction) {
                    Text("Capture Error")
                }
                
                Button(action: captureNSExceptionAction) {
                    Text("Capture NSException")
                }
                
                Button(action: captureTransaction) {
                    Text("Capture Transaction")
                }
                
                Button(action: {
                    viewModel.causeANR()
                }) {
                    Text(viewModel.anrText)
                }
            }
        }
    }
}

class ContentViewModel: ObservableObject {
    
    @Published var anrText = "Cause ANR"
    
    func causeANR() {
        
        var i = 0
        
        for _ in 0...5_000_000 {
            i += Int.random(in: 0...10)
            i -= 1
            
            anrText = "\(i)"
        }
        
        anrText = "Cause ANR"
    }
}

@available(watchOSApplicationExtension 7.0, *)
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
