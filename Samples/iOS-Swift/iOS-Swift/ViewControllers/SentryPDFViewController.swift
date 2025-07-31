import PDFKit

class SentryPDFViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        // Set up the PDF view and add it to the view hierarchy
        let pdfView = PDFView()
        view.addSubview(pdfView)

        pdfView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            pdfView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            pdfView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            pdfView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            pdfView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])

        // Load a PDF document
        guard let fileUrl = Bundle.main.url(forResource: "ProjectProposal", withExtension: "pdf"),
              let document = PDFDocument(url: fileUrl) else {
            preconditionFailure("Failed to load PDF document from bundle.")
        }
        pdfView.document = document
    }
}
