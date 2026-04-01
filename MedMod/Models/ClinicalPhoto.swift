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
    var sourceKind: String
    var sourceSystemName: String?
    var sourceRecordIdentifier: String?
    var sourceLastSyncedAt: Date?
    var sourceOfTruth: Bool

    var patient: PatientProfile?

    init(
        id: UUID = UUID(),
        captureDate: Date = Date(),
        anatomicalRegion: String,
        notes: String? = nil,
        filePath: String,
        linkedRecordID: String? = nil,
        sourceKind: String = ClinicalSourceKind.clinicianCaptured.rawValue,
        sourceSystemName: String? = nil,
        sourceRecordIdentifier: String? = nil,
        sourceLastSyncedAt: Date? = nil,
        sourceOfTruth: Bool = true
    ) {
        self.id = id
        self.captureDate = captureDate
        self.anatomicalRegion = anatomicalRegion
        self.notes = notes
        self.filePath = filePath
        self.linkedRecordID = linkedRecordID
        self.sourceKind = sourceKind
        self.sourceSystemName = sourceSystemName
        self.sourceRecordIdentifier = sourceRecordIdentifier
        self.sourceLastSyncedAt = sourceLastSyncedAt
        self.sourceOfTruth = sourceOfTruth
    }
}
