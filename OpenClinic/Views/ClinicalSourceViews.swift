import SwiftUI

private extension ClinicalSourceKind {
    var tint: Color {
        switch self {
        case .demoLocalCache: return .orange
        case .smartFHIR: return .blue
        case .clinicianCaptured: return .green
        case .patientGenerated: return .teal
        case .deviceImport: return .indigo
        case .manualEntry: return .secondary
        case .localAI: return .purple
        case .mixed: return .pink
        }
    }
}

private extension DocumentationLifecycleStatus {
    var tint: Color {
        switch self {
        case .draft: return .orange
        case .reviewed: return .blue
        case .signed: return .green
        }
    }
}

struct ClinicalSourceBadge: View {
    let descriptor: ClinicalSourceDescriptor
    var showSystem: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: descriptor.kind.iconName)
                .font(.system(size: 8.5, weight: .semibold))
            Text(showSystem ? (descriptor.systemName ?? descriptor.kind.label) : descriptor.kind.pillLabel)
                .clinicalPillText(weight: .semibold)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 2)
        .background(descriptor.kind.tint.opacity(0.12), in: Capsule())
        .foregroundStyle(descriptor.kind.tint)
    }
}

struct SourceOfTruthBadge: View {
    let authoritative: Bool

    var body: some View {
        Text(authoritative ? "Source" : "Supp.")
            .clinicalPillText(weight: .medium)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background((authoritative ? Color.green : Color.secondary).opacity(0.12), in: Capsule())
            .foregroundStyle(authoritative ? .green : .secondary)
    }
}

struct DocumentationStatusBadge: View {
    let status: DocumentationLifecycleStatus

    var body: some View {
        Text(status.label)
            .clinicalPillText(weight: .medium)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(status.tint.opacity(0.12), in: Capsule())
            .foregroundStyle(status.tint)
    }
}

struct ClinicalSourceSummaryRow: View {
    let descriptor: ClinicalSourceDescriptor
    var showAuthority: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                ClinicalSourceBadge(descriptor: descriptor)
                if showAuthority {
                    SourceOfTruthBadge(authoritative: descriptor.authoritative)
                }
            }

            HStack(spacing: 10) {
                if let systemName = descriptor.systemName, !systemName.isEmpty {
                    Label(systemName, systemImage: "server.rack")
                }
                if let recordIdentifier = descriptor.recordIdentifier, !recordIdentifier.isEmpty {
                    Label(recordIdentifier, systemImage: "number")
                }
                if let lastSyncedAt = descriptor.lastSyncedAt {
                    Label(lastSyncedAt.formatted(date: .abbreviated, time: .shortened), systemImage: "arrow.triangle.2.circlepath")
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            .clinicalFinePrint()
        }
    }
}
