import SwiftUI

struct iPadClinicalToolbar: View {
    @Namespace private var unionNamespace
    @State private var activeSection = "Home"

    let tools = [
        ("Tasks", "checklist"),
        ("Docs", "doc.text"),
        ("Rx", "pills"),
        ("Compliance", "checkmark.shield"),
        ("Home", "house"),
        ("Mail", "envelope"),
        ("Settings", "gearshape")
    ]

    var body: some View {
        // Approximating GlassEffectContainer & glassEffectUnion
        HStack(spacing: 0) {
            ForEach(tools, id: \.0) { tool in
                Button(action: {
                    withAnimation { activeSection = tool.0 }
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: tool.1)
                            .font(.system(size: 20))
                        Text(tool.0)
                            .font(.caption)
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 16)
                    .foregroundColor(activeSection == tool.0 ? .white : .purple)
                    // Fusing logic mock:
                    .background(
                        ZStack {
                            if activeSection == tool.0 {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.purple)
                                    .matchedGeometryEffect(id: "activeTab", in: unionNamespace)
                            }
                        }
                    )
                }
            }
        }
        .padding(4)
        .background(.ultraThinMaterial)
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.1), radius: 5)
    }
}
