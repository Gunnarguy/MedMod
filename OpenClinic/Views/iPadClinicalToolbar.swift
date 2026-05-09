import SwiftUI

struct iPadClinicalToolbar: View {
    @Namespace private var unionNamespace
    @Binding var activeSection: String
    var onAction: (String) -> Void

    let tools = [
        ("Chart", "doc.text"),
        ("Rx", "pills"),
        ("Encounter", "waveform.path.ecg.rectangle"),
        ("AI", "brain.head.profile"),
        ("Notes", "square.and.pencil"),
        ("Settings", "gearshape")
    ]

    var body: some View {
        Group {
            if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
                GlassEffectContainer {
                    HStack(spacing: 0) {
                        ForEach(tools, id: \.0) { tool in
                            toolbarButton(for: tool)
                                .glassEffectUnion(id: "mainToolbar", namespace: unionNamespace)
                        }
                    }
                    .buttonStyle(.glassProminent)
                    .tint(Color.white.opacity(0.8))
                }
            } else {
                HStack(spacing: 0) {
                    ForEach(tools, id: \.0) { tool in
                        toolbarButton(for: tool)
                    }
                }
                .padding(4)
                .background(.ultraThinMaterial)
                .cornerRadius(14)
                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
            }
        }
    }

    @ViewBuilder
    private func toolbarButton(for tool: (String, String)) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.3)) { activeSection = tool.0 }
            onAction(tool.0)
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
