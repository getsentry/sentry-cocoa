import PDFKit

class SentryPDFViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        let pdfView = PDFView()
        view.addSubview(pdfView)

        pdfView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            pdfView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            pdfView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            pdfView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            pdfView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])

        guard let fileUrl = Bundle.main.url(forResource: "ProjectProposal", withExtension: "pdf"),
              let document = PDFDocument(url: fileUrl) else {
            preconditionFailure("Failed to load PDF document from bundle.")
        }
        pdfView.document = document
    }
}
