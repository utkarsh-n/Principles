import SwiftUI
import HarmonicCore

struct DegreeProjectsView: View {
    var session: DegreeSession
    var body: some View {
        DegreeScroll {
            DegreeHeader(eyebrow: "Build and defend", title: "Fusion projects", subtitle: "Create a musical artifact and make its mathematics inspectable.")
            ForEach(DegreeCurriculum.projects) { project in
                NavigationLink { ProjectDetailView(project: project, session: session) } label: {
                    DegreePanel(project.title) {
                        Text(project.brief).font(.subheadline).foregroundStyle(HarmonicTheme.muted)
                        Text(session.project(project.id).submittedAt == nil ? "OPEN PROJECT" : "SUBMITTED FOR REVIEW").font(.system(.caption2, design: .monospaced)).foregroundStyle(HarmonicTheme.amber)
                    }
                }.buttonStyle(.plain).accessibilityIdentifier("project-\(project.id)")
            }
        }.navigationTitle("Projects").navigationBarTitleDisplayMode(.inline)
    }
}

struct ProjectDetailView: View {
    var project: DegreeProject
    var session: DegreeSession
    @State private var draft: ProjectDraft
    init(project: DegreeProject, session: DegreeSession) {
        self.project = project; self.session = session
        _draft = State(initialValue: session.project(project.id))
    }
    var body: some View {
        DegreeScroll {
            DegreeHeader(eyebrow: "A shared artifact", title: project.title, subtitle: project.brief)
            DegreePanel("Deliverables") { ForEach(project.deliverables, id: \.self) { Text("• \($0)").font(.subheadline) } }
            DegreePanel("Design statement") { TextField("What are you making, and why?", text: $draft.statement, axis: .vertical).lineLimit(3...8).accessibilityIdentifier("projectStatement") }
            DegreePanel("Mathematical and physical reasoning") { TextField("Derive, predict and explain your model", text: $draft.mathReasoning, axis: .vertical).lineLimit(4...10).accessibilityIdentifier("projectMath") }
            DegreePanel("Musical reasoning") { TextField("Explain your musical intention and decisions", text: $draft.musicalReasoning, axis: .vertical).lineLimit(4...10).accessibilityIdentifier("projectMusic") }
            DegreePanel("Attach notebook evidence") {
                if session.entries.isEmpty { Text("Save experiments and predictions in Studio first.").foregroundStyle(HarmonicTheme.muted) }
                ForEach(session.entries.filter { $0.projectID == nil }) { entry in
                    Toggle(entry.title, isOn: Binding(get: { draft.evidenceIDs.contains(entry.id) }, set: { included in
                        if included { draft.evidenceIDs.insert(entry.id) } else { draft.evidenceIDs.remove(entry.id) }
                    })).accessibilityIdentifier("attach-\(entry.id.uuidString)")
                }
            }
            DegreePanel("Self-review criteria") {
                ForEach(Array(project.acceptanceCriteria.enumerated()), id: \.offset) { index, criterion in
                    Toggle(criterion, isOn: Binding(get: { draft.checkedCriteria.contains(index) }, set: { checked in
                        if checked { draft.checkedCriteria.insert(index) } else { draft.checkedCriteria.remove(index) }
                    })).accessibilityIdentifier("criterion-\(index)")
                }
                Text("These checks document your review. They do not assign an automatic artistic or mastery grade.").font(.caption).foregroundStyle(HarmonicTheme.muted)
            }
            Button("Submit project to notebook") { session.updateProject(draft); _ = session.submitProject(project); draft = session.project(project.id) }
                .buttonStyle(DegreeAction(accent: HarmonicTheme.amber)).accessibilityIdentifier("submitProject")
            Text(session.status).font(.caption).foregroundStyle(HarmonicTheme.muted)
            DegreePanel("Scope") { Text(project.modelLimit).font(.caption).foregroundStyle(HarmonicTheme.muted) }
            SourceLinks(ids: project.sourceIDs)
        }.navigationTitle("Project studio").navigationBarTitleDisplayMode(.inline)
            .onChange(of: draft) { session.updateProject(draft) }
    }
}
