import SwiftUI

/// Represents the UI layout of the PDF document seen in Image 9
struct ClinicalPDFDocumentView: View {
    let patient: PatientProfile
    let visitNote: LocalClinicalRecord
    let clinicalDetails: ClinicalVisitNote

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack {
                Text("Visit Note - \(visitNote.dateRecorded, format: .dateTime.month().day().year())")
                    .foregroundColor(.purple)
                Spacer()
                Text("\(patient.lastName), \(patient.firstName)")
                    .font(.title3).bold().foregroundColor(.purple)
            }
            Divider()

            // Body Content mirroring Image 9
            VStack(alignment: .leading, spacing: 12) {
                Text("Chief Complaint:").bold()
                Text(clinicalDetails.ccHPI)

                Text("Exam:").bold()
                Text(clinicalDetails.examFindings)

                Text("Impression/Plan:").bold()
                Text(clinicalDetails.impressionsAndPlan)

                Text("Follow up in 1 year").bold()
            }
            .font(.system(size: 12))

            Spacer()

            // Footer
            VStack(alignment: .center) {
                Text("Electronically Signed By: \(patient.firstName) \(patient.lastName) Provider")
                    .font(.caption)
                    .underline()
            }
            .frame(maxWidth: .infinity)
        }
        .padding(40)
        .frame(width: 612, height: 792) // Standard US Letter size at 72 DPI
        .background(Color.white)
    }
}

/// Function to render the SwiftUI View into a PDF Data blob locally
@MainActor
func generatePDFLocally(patient: PatientProfile, record: LocalClinicalRecord, details: ClinicalVisitNote) -> URL? {
    let pdfView = ClinicalPDFDocumentView(patient: patient, visitNote: record, clinicalDetails: details)
    let renderer = ImageRenderer(content: pdfView)

    let url = FileManager.default.temporaryDirectory.appendingPathComponent("VisitNote_\(record.recordID).pdf")

    renderer.render { size, context in
        var box = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        guard let cgContext = CGContext(url as CFURL, mediaBox: &box, nil) else { return }

        cgContext.beginPDFPage(nil)
        context(cgContext)
        cgContext.endPDFPage()
        cgContext.closePDF()
    }

    return url
}
