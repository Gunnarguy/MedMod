import SwiftData
import Foundation

@Model
final class PatientProfile {
    @Attribute(.unique) var id: UUID
    var firstName: String
    var lastName: String
    var dateOfBirth: Date
    var gender: String
    var isSmoker: Bool

    @Relationship(deleteRule: .cascade) var clinicalRecords: [LocalClinicalRecord]?
    @Relationship(deleteRule: .cascade) var medications: [LocalMedication]?
    @Relationship(deleteRule: .cascade) var appointments: [Appointment]?

    init(id: UUID = UUID(), firstName: String, lastName: String, dateOfBirth: Date, gender: String, isSmoker: Bool = false) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.dateOfBirth = dateOfBirth
        self.gender = gender
        self.isSmoker = isSmoker
        self.clinicalRecords = []
        self.medications = []
        self.appointments = []
    }
}
