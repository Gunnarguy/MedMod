import Foundation

enum ClinicalSourceKind: String, CaseIterable, Sendable {
    case demoLocalCache = "demo_local_cache"
    case smartFHIR = "smart_fhir"
    case clinicianCaptured = "clinician_captured"
    case patientGenerated = "patient_generated"
    case deviceImport = "device_import"
    case manualEntry = "manual_entry"
    case localAI = "local_ai"
    case mixed = "mixed"

    var label: String {
        switch self {
        case .demoLocalCache: return "Demo Cache"
        case .smartFHIR: return "SMART on FHIR"
        case .clinicianCaptured: return "Clinician Captured"
        case .patientGenerated: return "Patient Reported"
        case .deviceImport: return "Device Import"
        case .manualEntry: return "Manual Entry"
        case .localAI: return "Local AI"
        case .mixed: return "Mixed Sources"
        }
    }

    var pillLabel: String {
        switch self {
        case .demoLocalCache: return "Demo"
        case .smartFHIR: return "SMART"
        case .clinicianCaptured: return "Capture"
        case .patientGenerated: return "Patient"
        case .deviceImport: return "Device"
        case .manualEntry: return "Manual"
        case .localAI: return "AI"
        case .mixed: return "Mixed"
        }
    }

    var iconName: String {
        switch self {
        case .demoLocalCache: return "shippingbox"
        case .smartFHIR: return "network"
        case .clinicianCaptured: return "stethoscope"
        case .patientGenerated: return "person.badge.plus"
        case .deviceImport: return "arrow.down.doc"
        case .manualEntry: return "square.and.pencil"
        case .localAI: return "brain.head.profile"
        case .mixed: return "square.stack.3d.up"
        }
    }
}

enum DocumentationLifecycleStatus: String, CaseIterable, Sendable {
    case draft
    case reviewed
    case signed

    var label: String {
        rawValue.capitalized
    }
}

struct ClinicalSourceDescriptor: Sendable {
    let kind: ClinicalSourceKind
    let systemName: String?
    let authoritative: Bool
    let lastSyncedAt: Date?
    let recordIdentifier: String?

    init(
        kind: ClinicalSourceKind,
        systemName: String? = nil,
        authoritative: Bool,
        lastSyncedAt: Date? = nil,
        recordIdentifier: String? = nil
    ) {
        self.kind = kind
        self.systemName = systemName
        self.authoritative = authoritative
        self.lastSyncedAt = lastSyncedAt
        self.recordIdentifier = recordIdentifier
    }

    init(
        kindRawValue: String,
        systemName: String? = nil,
        authoritative: Bool,
        lastSyncedAt: Date? = nil,
        recordIdentifier: String? = nil
    ) {
        self.init(
            kind: ClinicalSourceKind(rawValue: kindRawValue) ?? .manualEntry,
            systemName: systemName,
            authoritative: authoritative,
            lastSyncedAt: lastSyncedAt,
            recordIdentifier: recordIdentifier
        )
    }

    static let medModDemo = ClinicalSourceDescriptor(
        kind: .demoLocalCache,
        systemName: "MedMod Demo Dataset",
        authoritative: false
    )

    static let localAI = ClinicalSourceDescriptor(
        kind: .localAI,
        systemName: "MedMod On-Device Intelligence",
        authoritative: false
    )
}

extension PatientProfile {
    var sourceDescriptor: ClinicalSourceDescriptor {
        ClinicalSourceDescriptor(
            kindRawValue: sourceKind,
            systemName: sourceSystemName,
            authoritative: sourceOfTruth,
            lastSyncedAt: sourceLastSyncedAt,
            recordIdentifier: sourceRecordIdentifier
        )
    }
}

extension LocalClinicalRecord {
    var sourceDescriptor: ClinicalSourceDescriptor {
        ClinicalSourceDescriptor(
            kindRawValue: sourceKind,
            systemName: sourceSystemName,
            authoritative: sourceOfTruth,
            lastSyncedAt: sourceLastSyncedAt,
            recordIdentifier: sourceRecordIdentifier
        )
    }

    var documentationLifecycle: DocumentationLifecycleStatus {
        DocumentationLifecycleStatus(rawValue: documentationStatus) ?? .draft
    }
}

extension LocalMedication {
    var sourceDescriptor: ClinicalSourceDescriptor {
        ClinicalSourceDescriptor(
            kindRawValue: sourceKind,
            systemName: sourceSystemName,
            authoritative: sourceOfTruth,
            lastSyncedAt: sourceLastSyncedAt,
            recordIdentifier: sourceRecordIdentifier
        )
    }
}

extension Appointment {
    var sourceDescriptor: ClinicalSourceDescriptor {
        ClinicalSourceDescriptor(
            kindRawValue: sourceKind,
            systemName: sourceSystemName,
            authoritative: sourceOfTruth,
            lastSyncedAt: sourceLastSyncedAt,
            recordIdentifier: sourceRecordIdentifier
        )
    }
}

extension ClinicalPhoto {
    var sourceDescriptor: ClinicalSourceDescriptor {
        ClinicalSourceDescriptor(
            kindRawValue: sourceKind,
            systemName: sourceSystemName,
            authoritative: sourceOfTruth,
            lastSyncedAt: sourceLastSyncedAt,
            recordIdentifier: sourceRecordIdentifier
        )
    }
}
