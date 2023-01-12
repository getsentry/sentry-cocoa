import Foundation
import SentrySwiftUI
import SwiftUI

struct LoremIpsumView: View {
    
    @StateObject var viewModel = LoremIpsumViewModel()
    
    var body: some View {
        SentryTracedView("Lorem Ipsum") {
            Text(viewModel.text)
                .padding(16)
        }
    }
}

class LoremIpsumViewModel: ObservableObject {
    
    @Published var text = "Lorem Ipsum ..."
    
    init() {
        fetchLoremIpsum()
    }
    
    private func fetchLoremIpsum() {
        let dispatchQueue = DispatchQueue(label: "LoremIpsumViewModel")
        dispatchQueue.async {
            if let path = Bundle.main.path(forResource: "LoremIpsum", ofType: "txt") {
                if let contents = FileManager.default.contents(atPath: path) {
                    DispatchQueue.main.async {
                        self.text = String(data: contents, encoding: .utf8) ?? ""
                    }
                }
            }
        }
    }
}
