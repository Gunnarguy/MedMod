import SwiftUI
import SwiftData

struct EHRMainShellView: View {
    @State private var activeTab: TabSelection = .patient

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

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

            // On iPad, show the split-view dashboard; on iPhone, show the simpler list
            Group {
                #if os(iOS)
                if horizontalSizeClass == .regular {
                    iPadClinicalDashboard()
                } else {
                    PatientDashboardView()
                }
                #else
                iPadClinicalDashboard()
                #endif
            }
            .tabItem {
                Label("Patient", systemImage: "person.crop.circle")
            }
            .tag(TabSelection.patient)

            InboxView()
                .tabItem {
                    Label("IntraMail", systemImage: "envelope")
                }
                .tag(TabSelection.inbox)
        }
        #if os(iOS)
        .tabBarMinimizeBehavior(.onScrollDown)
        #endif
        .tint(.purple)
    }
}
