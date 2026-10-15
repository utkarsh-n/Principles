import SwiftUI
import HarmonicCore

struct HeroInstrument: View {
    var state: LabState
    var evaluation: LabEvaluation
    var motion: HarmonicMotion
    var body: some View {
        GeometryReader { geometry in
            let diameter = min(geometry.size.width, 318)
            InstrumentLensSurface(diameter: diameter, filteredTilt: SIMD2(motion.x, motion.y), motionActive: motion.isActive) {
                Canvas { context, size in
                    let d = min(size.width, size.height), center = CGPoint(x: d / 2, y: d / 2)
                    let circle = CGRect(x: 2, y: 2, width: d - 4, height: d - 4)
                    context.fill(Path(ellipseIn: circle), with: .linearGradient(Gradient(colors: [Color(red: 0.09, green: 0.12, blue: 0.14), Color(red: 0.025, green: 0.04, blue: 0.055)]), startPoint: .zero, endPoint: CGPoint(x: d, y: d)))
                    context.stroke(Path(ellipseIn: circle), with: .color(.white.opacity(0.25)), lineWidth: 1)
                    for index in 0..<60 {
                        let angle = Double(index) / 60 * 2 * Double.pi - .pi / 2
                        let r = d * 0.45, inner = r - (index % 5 == 0 ? 12 : 5)
                        var tick = Path()
                        tick.move(to: CGPoint(x: center.x + inner * cos(angle), y: center.y + inner * sin(angle)))
                        tick.addLine(to: CGPoint(x: center.x + r * cos(angle), y: center.y + r * sin(angle)))
                        context.stroke(tick, with: .color(.white.opacity(index % 5 == 0 ? 0.4 : 0.14)), lineWidth: 1)
                    }
                    if state.kind == .rhythm {
                        for channel in 0..<2 {
                            let count = Int(state.values[channel == 0 ? "beatsA" : "beatsB"] ?? 1)
                            let offset = channel == 0 ? 0 : (state.values["phase"] ?? 0) * .pi / 180
                            let r = d * (channel == 0 ? 0.39 : 0.32)
                            context.stroke(Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)), with: .color((channel == 0 ? HarmonicTheme.cyan : HarmonicTheme.violet).opacity(0.25)), lineWidth: 1)
                            for i in 0..<max(1, count) {
                                let angle = Double(i) / Double(max(1, count)) * 2 * .pi + offset - .pi / 2
                                let p = CGPoint(x: center.x + r * cos(angle), y: center.y + r * sin(angle))
                                context.fill(Path(ellipseIn: CGRect(x: p.x - 4, y: p.y - 4, width: 8, height: 8)), with: .color(channel == 0 ? HarmonicTheme.cyan : HarmonicTheme.violet))
                            }
                        }
                    } else {
                        var shape = Path()
                        let n = evaluation.waveform.count
                        for i in 0..<n {
                            let p = CGPoint(x: d * 0.20 + d * 0.60 * Double(i) / Double(max(1, n - 1)), y: d * 0.27 - evaluation.waveform[i] * d * 0.065)
                            if i == 0 { shape.move(to: p) } else { shape.addLine(to: p) }
                        }
                        context.stroke(shape, with: .color(HarmonicTheme.cyan), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                    }
                }
            } readout: {
                if let first = evaluation.readouts.first {
                    InstrumentLargeReadout(diameter: diameter, value: harmonicNumber(first.value), unit: first.unit,
                        meaning: first.title, spokenLabel: first.title)
                        .accessibilityIdentifier("heroReadout")
                }
            }.frame(maxWidth: .infinity)
        }.frame(height: 318)
    }
}

struct ModelWavePlot: View {
    var evaluation: LabEvaluation
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(evaluation.waveformCaption).font(.caption).foregroundStyle(HarmonicTheme.muted)
            HStack(spacing: 6) {
                VStack { Text("+1"); Spacer(); Text("0"); Spacer(); Text("−1") }.font(.system(.caption2, design: .monospaced)).foregroundStyle(HarmonicTheme.muted).frame(width: 23)
                Canvas { context, size in
                    var grid = Path()
                    for j in 0...4 {
                        let y = size.height * Double(j) / 4
                        grid.move(to: CGPoint(x: 0, y: y)); grid.addLine(to: CGPoint(x: size.width, y: y))
                    }
                    for j in 0...6 {
                        let x = size.width * Double(j) / 6
                        grid.move(to: CGPoint(x: x, y: 0)); grid.addLine(to: CGPoint(x: x, y: size.height))
                    }
                    context.stroke(grid, with: .color(.white.opacity(0.08)), lineWidth: 0.5)
                    var path = Path()
                    for (i, value) in evaluation.waveform.enumerated() {
                        let p = CGPoint(x: size.width * Double(i) / Double(max(1, evaluation.waveform.count - 1)), y: size.height * (0.5 - value * 0.44))
                        if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
                    }
                    context.stroke(path, with: .color(HarmonicTheme.cyan), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                }.frame(height: 148).accessibilityHidden(true)
            }
            HStack {
                Text("0")
                Spacer()
                Text("\(harmonicNumber(evaluation.waveformSpan)) \(evaluation.waveformUnit)")
            }.font(.system(.caption2, design: .monospaced)).foregroundStyle(HarmonicTheme.muted)
            Text(evaluation.waveformCaption.contains("pitch offset") ? "Vertical axis: pitch offset / 60 semitones." : "Vertical axis: relative amplitude or normalized mode shape.").font(.caption2).foregroundStyle(HarmonicTheme.muted)
        }.accessibilityElement(children: .combine)
    }
}

struct SpectrumPlot: View {
    var bins: [SpectrumBin]
    var caption: String
    private var maxFrequency: Double { max(1, bins.map(\.frequency).max() ?? 1) }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(caption).font(.caption).foregroundStyle(HarmonicTheme.muted)
            Canvas { context, size in
                for (index, bin) in bins.enumerated() {
                    let x = 4 + (size.width - 8) * bin.frequency / maxFrequency
                    let h = size.height * min(1, max(0, bin.amplitude))
                    context.fill(Path(roundedRect: CGRect(x: x - 2, y: size.height - h, width: 4, height: h), cornerRadius: 2), with: .color(index == 0 ? HarmonicTheme.amber : HarmonicTheme.violet))
                }
            }.frame(height: 116).accessibilityHidden(true)
            HStack { Text("0 Hz"); Spacer(); Text("\(harmonicNumber(maxFrequency)) Hz") }.font(.system(.caption2, design: .monospaced)).foregroundStyle(HarmonicTheme.muted)
            Text(bins.map { "\(harmonicNumber($0.frequency)) Hz: \(harmonicNumber($0.amplitude))" }.joined(separator: " · ")).font(.caption2).foregroundStyle(HarmonicTheme.muted)
        }.accessibilityElement(children: .combine)
    }
}
