import SwiftData
import Foundation

@Model
final class PatientProfile {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var medicalRecordNumber: String
    var firstName: String
    var lastName: String
    var dateOfBirth: Date
    var gender: String
    var isSmoker: Bool
    var primaryClinician: String?
    var preferredPharmacy: String?
    var carePlanSummary: String?
    var allergies: [String]
    var riskFlags: [String]
    var emergencyContactName: String?
    var emergencyContactPhone: String?
    var bloodType: String?

    @Relationship(deleteRule: .cascade) var clinicalRecords: [LocalClinicalRecord]?
    @Relationship(deleteRule: .cascade) var medications: [LocalMedication]?
    @Relationship(deleteRule: .cascade) var appointments: [Appointment]?
    @Relationship(deleteRule: .cascade) var clinicalPhotos: [ClinicalPhoto]?

    init(
        id: UUID = UUID(),
        medicalRecordNumber: String = UUID().uuidString,
        firstName: String,
        lastName: String,
        dateOfBirth: Date,
        gender: String,
        isSmoker: Bool = false,
        primaryClinician: String? = nil,
        preferredPharmacy: String? = nil,
        carePlanSummary: String? = nil,
        allergies: [String] = [],
        riskFlags: [String] = [],
        emergencyContactName: String? = nil,
        emergencyContactPhone: String? = nil,
        bloodType: String? = nil
    ) {
        self.id = id
        self.medicalRecordNumber = medicalRecordNumber
        self.firstName = firstName
        self.lastName = lastName
        self.dateOfBirth = dateOfBirth
        self.gender = gender
        self.isSmoker = isSmoker
        self.primaryClinician = primaryClinician
        self.preferredPharmacy = preferredPharmacy
        self.carePlanSummary = carePlanSummary
        self.allergies = allergies
        self.riskFlags = riskFlags
        self.emergencyContactName = emergencyContactName
        self.emergencyContactPhone = emergencyContactPhone
        self.bloodType = bloodType
        self.clinicalRecords = []
        self.medications = []
        self.appointments = []
        self.clinicalPhotos = []
    }

    var fullName: String {
        "\(firstName) \(lastName)"
    }

    var age: Int {
        Calendar.current.dateComponents([.year], from: dateOfBirth, to: .now).year ?? 0
    }
}
