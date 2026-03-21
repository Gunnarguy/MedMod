import SwiftUI



struct AgendaView: View {
    var body: some View {
        NavigationStack {
            Text("Daily Agenda")
                .navigationTitle("Agenda")
        }
    }
}

struct InboxView: View {
    var body: some View {
        NavigationStack {
            Text("IntraMail Inbox")
                .navigationTitle("Inbox")
        }
    }
}
