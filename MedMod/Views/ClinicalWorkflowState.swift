import Foundation
import Combine

@MainActor
final class ClinicalWorkflowState: ObservableObject {
    @Published var selectedAnatomy: String?
    @Published var generatedNote: ClinicalVisitNote?
    @Published var generatedPDFURL: URL?
    @Published var isProcessing = false

    func reset() {
        selectedAnatomy = nil
        generatedNote = nil
        generatedPDFURL = nil
        isProcessing = false
    }
}
