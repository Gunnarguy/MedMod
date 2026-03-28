import SwiftData
import Foundation

@Model
final class ClinicalPhoto {
    @Attribute(.unique) var id: UUID
    var captureDate: Date
    var anatomicalRegion: String
    var notes: String?
    var filePath: String
    var linkedRecordID: String?

    var patient: PatientProfile?

    init(
        id: UUID = UUID(),
        captureDate: Date = Date(),
        anatomicalRegion: String,
        notes: String? = nil,
        filePath: String,
        linkedRecordID: String? = nil
    ) {
        self.id = id
        self.captureDate = captureDate
        self.anatomicalRegion = anatomicalRegion
        self.notes = notes
        self.filePath = filePath
        self.linkedRecordID = linkedRecordID
    }
}
