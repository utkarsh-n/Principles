import SwiftUI
import HarmonicCore

enum HarmonicTheme {
    static let cyan = InstrumentPalette.actionCyan
    static let amber = InstrumentPalette.actionAmber
    static let violet = InstrumentPalette.spectrum
    static let ink = InstrumentPalette.displayInk
    static let muted = InstrumentPalette.secondaryInk
}

func harmonicNumber(_ value: Double) -> String {
    guard value.isFinite else { return "Unavailable" }
    if abs(value) >= 10000 { return value.formatted(.number.precision(.significantDigits(4))) }
    if abs(value) > 0 && abs(value) < 0.01 { return value.formatted(.number.precision(.significantDigits(3))) }
    return value.formatted(.number.precision(.fractionLength(0...2)))
}

struct DegreeHeader: View {
    var eyebrow: String
    var title: String
    var subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(eyebrow.uppercased()).font(.system(.caption2, design: .monospaced)).tracking(2).foregroundStyle(HarmonicTheme.cyan)
            Text(title).font(.system(.largeTitle, design: .rounded, weight: .semibold)).foregroundStyle(HarmonicTheme.ink)
            Text(subtitle).font(.subheadline).foregroundStyle(HarmonicTheme.muted).fixedSize(horizontal: false, vertical: true)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct DegreePanel<Content: View>: View {
    var title: String
    var content: Content
    init(_ title: String, @ViewBuilder content: () -> Content) { self.title = title; self.content = content() }
    var body: some View {
        InstrumentContentPanel {
            VStack(alignment: .leading, spacing: 12) {
                Text(title).font(.system(.headline, design: .rounded)).foregroundStyle(HarmonicTheme.ink)
                content
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct DegreeAction: ButtonStyle {
    var accent: Color = HarmonicTheme.cyan
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.subheadline, design: .rounded, weight: .semibold))
            .padding(.horizontal, 17).frame(minHeight: 46)
            .foregroundStyle(accent)
            .glassEffect(.regular.tint(accent.opacity(configuration.isPressed ? 0.22 : 0.08)).interactive(), in: .capsule)
    }
}

struct DegreeScroll<Content: View>: View {
    var content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) { content }
                .padding(.horizontal, 18).padding(.top, 12).padding(.bottom, 32)
                .frame(maxWidth: 760).frame(maxWidth: .infinity)
        }.scrollDismissesKeyboard(.interactively)
            .background(InstrumentDesignBackground())
    }
}

extension LabKind {
    var symbol: String {
        switch self {
        case .tone: "waveform"
        case .string: "guitars"
        case .intervals: "arrow.up.and.down"
        case .timbre: "chart.bar.xaxis"
        case .envelope: "waveform.path"
        case .rhythm: "metronome"
        case .scales: "pianokeys"
        case .harmony: "music.note.list"
        case .voiceLeading: "arrow.triangle.branch"
        case .resonance: "antenna.radiowaves.left.and.right"
        case .sampling: "square.dotted"
        case .filter: "line.3.horizontal.decrease"
        case .room: "cube.transparent"
        case .composition: "music.quarternote.3"
        }
    }
}
