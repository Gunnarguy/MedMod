import SwiftUI
import SwiftData

struct EHRMainShellView: View {
    @State private var activeTab: TabSelection = .patient

    enum TabSelection {
        case agenda, patient, inbox
    }

    var body: some View {
        TabView(selection: $activeTab) {
            AgendaView()
                .tabItem {
                    Label("Agenda", systemImage: "calendar")
                }
                .tag(TabSelection.agenda)

            PatientDashboardView()
                .tabItem {
                    Label("Patient", systemImage: "person.crop.circle")
                }
                .tag(TabSelection.patient)

            InboxView()
                .tabItem {
                    Label("IntraMail", systemImage: "envelope")
                }
                .badge(9)
                .tag(TabSelection.inbox)
        }
        .tint(.purple)
    }
}

#Preview {
    EHRMainShellView()
        .modelContainer(for: PatientProfile.self, inMemory: true)
}
