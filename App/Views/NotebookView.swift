import SwiftUI
import HarmonicCore

struct NotebookView: View {
    var session: DegreeSession
    @State private var query = ""
    private var filtered: [NotebookEntry] {
        session.entries.filter { query.isEmpty || ($0.title + " " + $0.note).localizedCaseInsensitiveContains(query) }
    }
    var body: some View {
        DegreeScroll {
            DegreeHeader(eyebrow: "Your work, preserved", title: "Notebook", subtitle: "Predictions, configurations, musical choices and revisions become evidence you can replay.")
            if session.entries.isEmpty {
                DegreePanel("Start an investigation") {
                    Text("Save a run or commit a prediction in the Studio. Your notebook will retain the state and reasoning.").foregroundStyle(HarmonicTheme.muted)
                    Button("Open Studio") { session.tab = 1 }.buttonStyle(DegreeAction())
                }
            }
            ForEach(filtered) { entry in
                NavigationLink { NotebookDetailView(entry: entry, session: session) } label: {
                    DegreePanel(entry.title) {
                        HStack {
                            Text(entry.date.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(HarmonicTheme.muted)
                            Spacer()
                            Text(entry.evidence.map { $0.matched ? "MATCHED" : "REVISE" } ?? entry.kind.uppercased()).font(.system(.caption2, design: .monospaced)).foregroundStyle(HarmonicTheme.amber)
                        }
                        if !entry.note.isEmpty { Text(entry.note).font(.subheadline).lineLimit(3).foregroundStyle(HarmonicTheme.muted) }
                    }
                }.buttonStyle(.plain).accessibilityIdentifier("notebookEntry-\(entry.id.uuidString)")
            }
        }.searchable(text: $query, prompt: "Find your reasoning")
            .navigationTitle("Notebook").navigationBarTitleDisplayMode(.inline)
    }
}

struct NotebookDetailView: View {
    var entry: NotebookEntry
    var session: DegreeSession
    var isSnapshot = false
    @Environment(\.dismiss) private var dismiss
    @State private var deleting = false
    var body: some View {
        DegreeScroll {
            DegreeHeader(eyebrow: entry.kind, title: entry.title, subtitle: entry.date.formatted())
            HStack {
                Button { session.restore(entry) } label: { Label("Restore in Studio", systemImage: "arrow.uturn.backward") }
                    .buttonStyle(DegreeAction()).accessibilityIdentifier("restoreEntry")
                ShareLink(item: entry.markdown) { Image(systemName: "square.and.arrow.up") }.buttonStyle(DegreeAction()).accessibilityLabel("Export investigation")
            }
            if let evidence = entry.evidence {
                DegreePanel("Prediction evidence") {
                    Text(evidence.prompt)
                    Text("Your answer: \(harmonicNumber(evidence.entered)) \(evidence.unit)")
                    Text("Model: \(harmonicNumber(evidence.expected)) \(evidence.unit) · tolerance ±\(harmonicNumber(evidence.tolerance))").foregroundStyle(HarmonicTheme.cyan)
                    Text(evidence.matched ? "Matched this numerical challenge." : "The prediction differed from the model.").foregroundStyle(HarmonicTheme.amber)
                }
            }
            DegreePanel("Your reasoning") { Text(entry.note.isEmpty ? "No written reasoning was added." : entry.note).textSelection(.enabled).accessibilityIdentifier("notebookReasoning") }
            DegreePanel("Captured configuration") {
                ForEach(entry.state.values.sorted(by: { $0.key < $1.key }), id: \.key) { item in
                    LabeledContent(item.key, value: harmonicNumber(item.value)).font(.system(.caption, design: .monospaced))
                }
                Text("Partials: \(entry.state.harmonics.map(harmonicNumber).joined(separator: ", "))").font(.caption)
                Text("Phrase: \(entry.state.steps.map { $0 < 0 ? "rest" : noteLabel($0) }.joined(separator: " · "))").font(.caption)
            }
            DegreePanel("Governing model") { Text(entry.equation).font(.system(.body, design: .monospaced)); Text(entry.modelLimit).font(.caption).foregroundStyle(HarmonicTheme.muted) }
            if !entry.attachments.isEmpty {
                DegreePanel("Attached investigations") {
                    ForEach(entry.attachments) { attached in
                        NavigationLink(attached.title) { NotebookDetailView(entry: attached, session: session, isSnapshot: true) }
                            .accessibilityIdentifier("attachment-\(attached.id.uuidString)")
                    }
                }
            }
            SourceLinks(ids: entry.sourceIDs)
            if !isSnapshot {
                Button("Delete this record", role: .destructive) { deleting = true }.padding(.vertical, 12).accessibilityIdentifier("deleteEntry")
            }
        }.navigationTitle("Investigation").navigationBarTitleDisplayMode(.inline)
            .confirmationDialog("Delete this notebook record?", isPresented: $deleting) {
                Button("Delete", role: .destructive) {
                    guard !isSnapshot else { return }
                    session.delete(entry.id); dismiss()
                }
            }
    }
}

struct DegreeReviewView: View {
    var session: DegreeSession
    var body: some View {
        DegreeScroll {
            DegreeHeader(eyebrow: "Return and transfer", title: "Review", subtitle: "Reconstruct an earlier idea, change a condition, and explain what survives.")
            DegreePanel("Evidence is specific") {
                Text("A matched prediction establishes that task. Revisit an investigation after a delay, attempt a changed case without the old answer, and save the new reasoning.").foregroundStyle(HarmonicTheme.muted)
            }
            if session.reviews.isEmpty { DegreePanel("Your review queue") { Text("Checked predictions will appear here. You can also revisit any saved experiment from the notebook.").foregroundStyle(HarmonicTheme.muted) } }
            ForEach(session.reviews) { entry in
                DegreePanel(entry.title) {
                    Text("Investigated \(entry.date.formatted(date: .abbreviated, time: .omitted)).").font(.caption).foregroundStyle(HarmonicTheme.muted)
                    Text("Restore it, change one control, derive your prediction without viewing the old result, then commit another answer.").font(.subheadline)
                    Button("Revisit in Studio") { session.beginReview(entry) }.buttonStyle(DegreeAction()).accessibilityIdentifier("review-\(entry.id.uuidString)")
                }
            }
            DegreePanel("Synthesis prompts") {
                Text("Explain a tuning choice using both ratios and musical context.\n\nUse the same exponential decay in a sound envelope and a physical model.\n\nDesign a phrase, then defend a revision under a new constraint.").font(.subheadline)
            }
        }.navigationTitle("Review").navigationBarTitleDisplayMode(.inline)
    }
}
