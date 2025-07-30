import Foundation
import SentrySampleShared
import SentrySwiftUI
import SwiftUI

struct LoremIpsumView: View {
    
    @StateObject var viewModel = LoremIpsumViewModel()
    
    var body: some View {
//        SentryTracedView("Lorem Ipsum") {
            VStack {
                checkBody()
                Text(viewModel.text)
                    .padding(16)
            }

//        }
    }
}

class LoremIpsumViewModel: ObservableObject {
    
    @Published var text = "Lorem Ipsum ..."
    
    init() {
        fetchLoremIpsum()
    }
    
    private func fetchLoremIpsum() {
        checkBody()

        let dispatchQueue = DispatchQueue(label: "LoremIpsumViewModel")
        dispatchQueue.async {
            if let path = BundleResourceProvider.loremIpsumTextFilePath {
                if let contents = FileManager.default.contents(atPath: path) {
                    DispatchQueue.main.async {
                        self.text = String(data: contents, encoding: .utf8) ?? ""
                    }
                }
            }
        }
    }
}
