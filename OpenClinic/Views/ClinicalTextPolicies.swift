import SwiftUI

private struct ClinicalAdaptiveFontModifier: ViewModifier {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let compactSize: CGFloat
    let regularSize: CGFloat
    let weight: Font.Weight
    let design: Font.Design
    let tracking: CGFloat

    private var resolvedPointSize: CGFloat {
        horizontalSizeClass == .compact ? compactSize : regularSize
    }

    func body(content: Content) -> some View {
        content
            .font(.system(size: resolvedPointSize, weight: weight, design: design))
            .tracking(tracking)
    }
}

extension View {
    func clinicalCompactText() -> some View {
        lineLimit(1)
            .truncationMode(.tail)
            .minimumScaleFactor(0.9)
    }

    func clinicalFinePrint(weight: Font.Weight = .medium) -> some View {
        modifier(ClinicalAdaptiveFontModifier(
            compactSize: 10,
            regularSize: 11,
            weight: weight,
            design: .rounded,
            tracking: 0.15
        ))
    }

    func clinicalFinePrintMonospaced(weight: Font.Weight = .medium) -> some View {
        modifier(ClinicalAdaptiveFontModifier(
            compactSize: 10,
            regularSize: 11,
            weight: weight,
            design: .monospaced,
            tracking: 0.1
        ))
    }

    func clinicalMicroLabel(weight: Font.Weight = .medium) -> some View {
        modifier(ClinicalAdaptiveFontModifier(
            compactSize: 9,
            regularSize: 10,
            weight: weight,
            design: .rounded,
            tracking: 0.2
        ))
    }

    func clinicalMicroMonospaced(weight: Font.Weight = .medium) -> some View {
        modifier(ClinicalAdaptiveFontModifier(
            compactSize: 9,
            regularSize: 10,
            weight: weight,
            design: .monospaced,
            tracking: 0.15
        ))
    }

    func clinicalPillText(weight: Font.Weight = .medium) -> some View {
        modifier(ClinicalAdaptiveFontModifier(
            compactSize: 8.5,
            regularSize: 9.5,
            weight: weight,
            design: .rounded,
            tracking: 0.08
        ))
        .fixedSize(horizontal: true, vertical: false)
        .lineLimit(1)
        .truncationMode(.tail)
        .minimumScaleFactor(0.9)
        .padding(.horizontal, 0.5)
    }

    func clinicalRowSummaryText(lines: Int = 1) -> some View {
        lineLimit(lines)
            .truncationMode(.tail)
    }

    func clinicalNarrativeText() -> some View {
        fixedSize(horizontal: false, vertical: true)
    }
}
