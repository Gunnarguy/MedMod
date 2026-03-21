import SwiftUI
import SwiftData

struct PatientDashboardView: View {
    @Query var patients: [PatientProfile]

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                // Background Layer: Edge-to-edge content
                List {
                    // Spacer to prevent content from hiding behind the floating header
                    Spacer().frame(height: 100).listRowBackground(Color.clear)

                    Section {
                        NavigationLink(destination: Text("Clipboard")) {
                            Label("Patient Clipboard", systemImage: "doc.clipboard")
                        }
                        NavigationLink(destination: Text("Data")) {
                            Label("Patient Data", systemImage: "chart.xyaxis.line")
                        }
                        if let patient = patients.first {
                            NavigationLink(destination: ClinicalExamView(patient: patient)) {
                                Label("3D Clinical Exam (AI)", systemImage: "macwindow.badge.plus")
                                    .foregroundColor(.purple)
                            }
                        }
                        NavigationLink(destination: ClinicalAssistantView()) {
                            Label("Clinical Assistant (Tool Calling)", systemImage: "sparkles.rectangle")
                                .foregroundColor(.blue)
                        }
                        NavigationLink(destination: VisitHistoryView()) {
                            Label("Visits", systemImage: "bed.double")
                        }
                        NavigationLink(destination: Text("Chart Notes")) {
                            Label("Chart Notes", systemImage: "folder")
                        }
                        NavigationLink(destination: RxView()) {
                            Label("Rx", systemImage: "pills")
                        }
                        NavigationLink(destination: Text("Sticky Note")) {
                            Label("Sticky Note", systemImage: "note.text")
                        }
                        NavigationLink(destination: Text("Attachments")) {
                            Label("Attachments", systemImage: "paperclip")
                        }
                    }
                }
#if os(iOS)
                .listStyle(.insetGrouped)
#endif

                // Foreground Layer: Custom Header replacing the solid purple bar
                if let patient = patients.first {
                    LiquidGlassPatientHeader(patient: patient)
                } else {
                    // Fallback for preview/empty state
                    VStack {
                        Text("No patient selected")
                            .padding()
                            .background(.ultraThinMaterial)
                            .cornerRadius(12)
                    }.padding(.top, 20)
                }
            }
        }
    }
}

struct LiquidGlassPatientHeader: View {
    let patient: PatientProfile

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .frame(width: 60, height: 60)
                .foregroundColor(.gray)

            VStack(alignment: .leading, spacing: 4) {
                Text("\(patient.firstName) \(patient.lastName)")
                    .font(.headline)
                    .foregroundColor(.primary)
                Text(patient.dateOfBirth, format: .dateTime.month().day().year())
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()

            Button(action: { /* Share Action */ }) {
                Image(systemName: "square.and.arrow.up")
                    .font(.title2)
            }
        }
        .padding()
        .background(.regularMaterial) // Approximation of "Liquid Glass"
        .cornerRadius(16)
        .shadow(radius: 5)
        .padding(.horizontal)
        .padding(.top, 10)
    }
}

#Preview {
    PatientDashboardView()
        .modelContainer(for: PatientProfile.self, inMemory: true)
}
