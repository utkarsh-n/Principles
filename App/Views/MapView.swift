import SwiftUI
import HarmonicCore

struct DegreeMapView: View {
    var session: DegreeSession
    var body: some View {
        DegreeScroll {
            DegreeHeader(eyebrow: "Music · Mathematics · Physics", title: "Principles", subtitle: "Hear a relationship. Open its mathematics. Make something with it.")
            DegreePanel("Your fusion degree") {
                HStack {
                    InstrumentMetricReadout("MODULES", value: String(DegreeCurriculum.modules.count), unit: "")
                    InstrumentMetricReadout("LESSONS", value: String(DegreeCurriculum.lessons.count), unit: "")
                    InstrumentMetricReadout("PREDICTIONS", value: String(session.matchedPredictions), unit: "matched", color: HarmonicTheme.amber)
                }
                Text("\(session.investigatedLessons.count) lessons have saved investigations. Follow the route or open any instrument.").font(.caption).foregroundStyle(HarmonicTheme.muted)
                Button { session.open(.tone) } label: { Label("Open the sound instrument", systemImage: "waveform") }
                    .buttonStyle(DegreeAction()).accessibilityIdentifier("startStudio")
            }
            ForEach(DegreeCurriculum.modules) { module in
                NavigationLink {
                    ModuleDetailView(module: module, session: session)
                } label: {
                    DegreePanel(module.title) {
                        HStack(alignment: .top, spacing: 12) {
                            Text(String(format: "%02d", module.stage)).font(.system(.title2, design: .monospaced)).foregroundStyle(HarmonicTheme.cyan)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(module.subtitle).foregroundStyle(HarmonicTheme.muted).font(.subheadline)
                                Text("\(module.lessons.count) investigations · \(module.lessons.filter { session.investigatedLessons.contains($0.id) }.count) saved").font(.caption).foregroundStyle(HarmonicTheme.amber)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right").foregroundStyle(HarmonicTheme.cyan)
                        }
                    }
                }.buttonStyle(.plain).accessibilityIdentifier("module-\(module.id)")
            }
            DegreePanel("Two lenses, one object") {
                Text("The scientific model explains what the instrument does. Musical interpretation asks what you can do with it. Western tonal studies are identified as a particular tradition; physical equations do not establish universal aesthetic rules.").font(.subheadline).foregroundStyle(HarmonicTheme.muted)
            }
        }.navigationTitle("Degree map").navigationBarTitleDisplayMode(.inline)
    }
}

struct ModuleDetailView: View {
    var module: DegreeModule
    var session: DegreeSession
    var body: some View {
        DegreeScroll {
            DegreeHeader(eyebrow: "Module \(module.stage)", title: module.title, subtitle: module.subtitle)
            if !module.prerequisiteIDs.isEmpty {
                DegreePanel("Useful foundations") {
                    ForEach(module.prerequisiteIDs, id: \.self) { id in
                        if let prior = DegreeCurriculum.modules.first(where: { $0.id == id }) {
                            Text(prior.title).font(.subheadline).foregroundStyle(HarmonicTheme.cyan)
                        }
                    }
                    Text("You can explore freely. These connections explain the suggested sequence.").font(.caption).foregroundStyle(HarmonicTheme.muted)
                }
            }
            ForEach(module.lessons) { lesson in
                NavigationLink { LessonDetailView(lesson: lesson, session: session) } label: {
                    DegreePanel(lesson.title) {
                        Text(lesson.concept).font(.subheadline).foregroundStyle(HarmonicTheme.muted)
                        Label(LabCatalog.definition(for: LabKind(rawValue: lesson.labID) ?? .tone).title, systemImage: "waveform")
                            .font(.caption).foregroundStyle(HarmonicTheme.cyan)
                    }
                }.buttonStyle(.plain).accessibilityIdentifier("lesson-\(lesson.id)")
            }
        }.navigationTitle(module.title).navigationBarTitleDisplayMode(.inline)
    }
}

struct LessonDetailView: View {
    var lesson: DegreeLesson
    var session: DegreeSession
    var body: some View {
        DegreeScroll {
            DegreeHeader(eyebrow: "A bridge investigation", title: lesson.title, subtitle: lesson.concept)
            Button { session.open(lesson) } label: { Label("Open this investigation", systemImage: "play.fill") }
                .buttonStyle(DegreeAction(accent: HarmonicTheme.amber)).accessibilityIdentifier("openLesson")
            DegreePanel("Explore") {
                ForEach(Array(lesson.steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 10) {
                        Text(String(index + 1)).font(.system(.body, design: .monospaced)).foregroundStyle(HarmonicTheme.cyan)
                        Text(step).font(.subheadline)
                    }
                }
            }
            DegreePanel("Understand") {
                Text(lesson.explanation).font(.subheadline)
                Text(lesson.equation).font(.system(.body, design: .monospaced)).foregroundStyle(HarmonicTheme.cyan).textSelection(.enabled)
            }
            DegreePanel("Predict") { Text(lesson.prediction).font(.subheadline) }
            DegreePanel("Math and physics") { Text(lesson.mathTask).font(.subheadline) }
            DegreePanel("Musical work") { Text(lesson.musicTask).font(.subheadline); Text(lesson.creationTask).font(.subheadline).foregroundStyle(HarmonicTheme.amber) }
            DegreePanel("Model and scope") { Text(lesson.modelLimit).font(.caption).foregroundStyle(HarmonicTheme.muted) }
            SourceLinks(ids: lesson.sourceIDs)
        }.navigationTitle("Investigation").navigationBarTitleDisplayMode(.inline)
    }
}

struct SourceLinks: View {
    var ids: [String]
    var body: some View {
        DegreePanel("Sources") {
            ForEach(ids, id: \.self) { id in
                if let source = DegreeCurriculum.sources.first(where: { $0.id == id }), let url = URL(string: source.url) {
                    Link(destination: url) { Label(source.title, systemImage: "arrow.up.right") }.font(.caption).foregroundStyle(HarmonicTheme.cyan).accessibilityIdentifier("source-\(source.id)")
                }
            }
        }
    }
}
