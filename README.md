# Principles

A native SwiftUI iPhone fusion studio for Music Theory, Mathematics and Physics, using the Metro Station design system. The curriculum contains 12 modules, 48 original investigations, 14 parameterized instruments and four projects. Research and source mapping are in [Documentation/Research.md](Documentation/Research.md).

## Use the studio

Start in Map, choose a module and investigation, and open its actual instrument. Each investigation supplies a configuration, experiment steps, an explanation, a formal task and musical work. Studio also supports free exploration of tone, string modes, tuning and beats, additive timbre, exponential decay, polyrhythm, scales, triads, voice movement, resonance, sampling, RC response, room modes and sixteen-step composition.

Readouts and controls stay anchored. The underlying metal and isolated native glass lens may respond to motion; motion changes presentation only. Native sliders, exact-value editing and fine steppers complement the visual instrument. Auditions have a twelve-second sample-clock deadline; leaving Studio, backgrounding or an output interruption stops them. Sound, haptics and motion can be enabled separately in Instrument settings.

Keyboard comparisons support four simultaneous selected pitches. Main auditions use the generated model recipe; scale auditions traverse its ascending pitch pattern. Composition saves a sixteen-slot monophonic phrase with rests and an eight-partial synthesis recipe. Every sounding step starts its own decaying envelope; edits within a held step preserve the envelope and phase.

## Preserve the work

Predict captures a changed-setting numerical question and its starting state before accepting an answer. The notebook retains the prompt, answer, expected result, tolerance, equation, model limits, configuration and reasoning. Save run also retains partials, selected keys and phrase slots. Restore opens a saved state without rewriting the original record. Exports include readable source-linked Markdown.

Projects require a design statement, mathematical/physical reasoning, musical reasoning, saved notebook evidence and self-review criteria. Submission snapshots its attachments so an exported project preserves the underlying investigations. These are submissions for review; checked predictions and project self-review are reported with their actual scope. The Review queue stays open until a fresh matching prediction is recorded.

## Build

Use Xcode 27 and an iOS 27 iPhone destination. Generate the project with `xcodegen generate`. The project separates HarmonicCore, the native app, app-hosted session/PCM tests and UI tests. The portable Swift package exposes HarmonicCore for macOS/iOS validation.

For a Documents checkout that stalls during Xcode coordination, use an identical temporary build copy. Verify production-source parity before installing its product. No runtime backend or downloaded model is required.

## Verification

[Documentation/QA/Validation.md](Documentation/QA/Validation.md) records completed checks, precise evidence and remaining runtime work. Simulator testing precedes physical phone automation. Mathematical tests and returned PCM analysis are distinct from actual speaker listening, felt haptics, motion behavior and accessibility acceptance.

QA launch arguments use isolated app-private notebooks: `--qa-id <name> --qa-reset --qa-lab <instrument>`. They never reset the ordinary learner notebook. Omit QA arguments for regular use.


## Public snapshot

See [PUBLICATION.md](PUBLICATION.md) for publication exclusions and setup requirements.
