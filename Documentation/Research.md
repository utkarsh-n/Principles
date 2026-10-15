# Principles: music, mathematics and physics as a learning instrument

Research date: October 13, 2026. Curriculum content is an original synthesis for personal self-study. The source map below was inspected before implementation began. Principles is a bounded learning studio; it does not award an accredited degree, certify musicianship, reproduce a university program, or replace a teacher, ensemble, instrument practice or physical acoustics laboratory.

## What the curriculum combines

Music study requires making and hearing music alongside notation, concepts and analysis. MIT's [Fundamentals of Music syllabus](https://ocw.mit.edu/courses/21m-051-fundamentals-of-music-spring-2007/pages/syllabus/) combines ear development, rhythm, pitch, scales and harmony with practical work. Its [Harmony and Counterpoint I](https://ocw.mit.edu/courses/21m-301-harmony-and-counterpoint-i-spring-2005/pages/syllabus/) and [II](https://ocw.mit.edu/courses/21m-302-harmony-and-counterpoint-ii-spring-2005/pages/syllabus/) place harmonic and formal conventions within a particular European historical idiom and connect analysis to composition and performance. Principles names that context whenever it uses tonal functions or voice-leading conventions.

Music also provides a concrete reason to learn mathematical models. Illinois [PHYS 406](https://courses.physics.illinois.edu/phys406/sp2017/406pom_course_description.html) connects musical acoustics, tuning, instruments, hearing and room acoustics to differential equations, Fourier analysis and laboratory investigation. MIT [18.03SC](https://ocw.mit.edu/courses/18-03sc-differential-equations-fall-2011/pages/syllabus/syllabus/) and [6.003](https://ocw.mit.edu/courses/6-003-signals-and-systems-fall-2011/pages/syllabus/) supply a progression through oscillation, superposition, response and sampled signals. Principles borrows their subject relationships, while authoring its own small investigations and creation tasks.

The studio should not conclude that music is reducible to acoustic ratios. MIT's [Introduction to World Music](https://ocw.mit.edu/courses/21m-030-introduction-to-world-music-spring-2013/pages/syllabus/) studies sound together with cultural setting, purpose, listening and written interpretation. Its [Music Composition](https://ocw.mit.edu/courses/21m-351-music-composition-fall-2008/pages/syllabus/) also reaches beyond common-practice tonality. Principles therefore treats major/minor harmony as one named working vocabulary, supports original creation, and asks learners to distinguish measurable sound from interpretive claims.

## Learning contract

Each of the 48 lessons contains a concept, a real instrument route, an equation or declared formal relationship, an initial prediction, three concrete investigation steps, an explanation, a calculation, a music-making task, sources and a model boundary. Lessons reuse 14 instruments; 48 lesson records do not mean 48 independent physical simulators.

The interaction loop is: predict, manipulate one cause, listen or inspect, compare representations, calculate, create, explain, then revisit a changed case. A saved prediction or completed task is evidence of practice. Mathematical acceptance checks establish only their declared criteria; a report should not claim artistic quality, cultural authenticity, trained hearing, performance competence or durable mastery from a button press.

Measurements and listening serve different purposes. A learner can calculate a frequency difference and separately describe its audible effect. Personal listening notes have no fabricated correctness score. When an answer is checkable, preserve the inputs, units, expected value, tolerance and model version. Keep revisions and exportable creations so later work can demonstrate transfer, not only exposure.

## Progression and prerequisites

The Swift source is the authoritative lesson metadata. Prerequisites suggest a route without preventing exploration.

| Stage | Module | Four investigations | Main mathematical bridge |
|---|---|---|---|
| 1 | Sound as a controllable signal | Period/frequency; amplitude/energy; phase; hearing and representation | Sine functions, inverse quantities, units, amplitude ratios |
| 1 | Rhythm and rational time | Durations; grouping; simultaneous cycles; syncopation | Fractions, tempo conversion, least common multiples, cyclic indices |
| 1 | Pitch, ratios and intervals | Octaves; interval ratios; cents; beats | Products, powers, logarithms, interference |
| 2 | Timbre and Fourier thinking | Partial sums; spectral balance; harmonic-family rules; absent fundamental | Superposition, harmonic frequency, spectral descriptors |
| 2 | Instruments and stored energy | String length; tension/density; resonance; decay | Wave speed, boundary modes, response, exponential envelopes |
| 2 | Scales and tuning choices | Equal division; major steps; minor variants; contextual tuning choices | Exponentials, pitch-class arithmetic, cents deviation |
| 2 | Melody as a transformation | Contour; transposition; inversion; phrase | Signed intervals, vectors, symmetry, duration sums |
| 3 | Chords and tonal function | Triads; inversions; sevenths; cadential contrast | Pitch sets, permutations, interval structure, named tonal syntax |
| 3 | Voice leading and independent lines | Common pitch versus held voice; inversion/motion; limits of cost; separate line studies | Register-sorted endpoint motion, signed displacement, interval sequences |
| 3 | Digital sound and acoustic space | Sampling; finite observation; filtering; room relationships | Aliasing, sample rate/window length, response, propagation |
| 3 | Form, listening and context | Motif; variation; contrast; contextual interpretation | Transformation, event patterns, structural comparison; qualitative judgment |
| 4 | A reproducible composition | Brief; predicted model; revision; evidence portfolio | Constraint checking, model provenance and written reasoning |

Four substantial fusion projects connect the modules: a tuning comparison composition, an imaginary-instrument design with separately auditioned components, an exact/quantized rhythmic study, and an annotated composition portfolio. Each requires a saved creation, quantitative evidence, listening observations and revision rationale. They are original briefs rather than copied university assignments. Components from different instruments are retained as separate recipes; no automatic patching or multi-track arrangement is claimed.

## Supported model contracts

The implementation should use the same parameters for sound generation, plots and numerical readouts. A preset is an inspectable starting state. Changing playback speed must not silently change the physical frequency, tuning, tempo or duration relationships being studied. Stop and scene inactivity should terminate sound; haptics remain optional and meaningful.

| Instrument ID | Mathematical contract | Boundary that must remain visible |
|---|---|---|
| `tone` | Generated sinusoid; frequency/period, digital amplitude and phase | Digital signal, not calibrated sound pressure or biological hearing model |
| `string` | Ideal stretched-string modes: v = √(T/μ), fₙ = nv/(2L) | Uniform density, fixed ends, small transverse displacement; no body radiation, stiffness or nonlinear contact |
| `intervals` | Frequency ratios, 1200 log₂(f₂/f₁), and simple-tone beat rate | Ratio and beating describe physical relationships; they do not determine aesthetic consonance |
| `timbre` | A finite additive sum of declared partials | Spectrum alone does not reproduce a named instrument or guarantee a perceived missing fundamental |
| `envelope` | Exponential amplitude decay and half-life | An authored synthesis control, not ADSR or a measured instrument envelope |
| `rhythm` | Two exact uniform pulse trains per four-quarter-note cycle, with a declared phase offset | Finite parameter-defined pulses; no unmeasured human timing or tradition-specific groove model |
| `scales` | Major, natural minor, harmonic minor and ascending melodic minor with explicit root in 12-TET | Named Western collections, not a universal taxonomy or a complete raga/maqam system |
| `harmony` | Explicit note sets and named tonal chord vocabulary | Chord labels and functions belong to their stated idiom; enharmonic spelling matters beyond pitch-class arithmetic |
| `voiceLeading` | Source major triad and destination triad with register-sorted endpoint displacements | No optimal assignment, voice identity, contrapuntal rule checker or objective composition grade |
| `resonance` | Declared driven damped oscillator response | Linear steady-state model; exclude unimplemented nonlinear, coupled or time-domain behavior |
| `sampling` | 256 exact generated samples and a mathematically folded alias | No FFT; sample trace and hypothetical DFT-bin calculation are distinguished; audio plays the original frequency at the separate real device rate |
| `filter` | Exact unloaded first-order RC sinusoidal steady-state magnitude and phase | No transient charging, full-spectrum live processing, component variation or hardware response claim |
| `room` | One ideal axial pressure mode p(x) ∝ cos(nπx/L), with fₙ = nc/(2L) | No measured room calibration, 3D modes, echoes, diffuse-field reverb or head-related transfer function |
| `composition` | Sixteen explicit MIDI/rest slots at sixteenth-note spacing, plus reproducible synthesis | One 4/4 bar, not a notation engraver, arbitrary-duration editor, DAW, live ensemble or automatic artistic evaluator |

These contracts are requirements for teaching routes, not a claim that all optional mathematical details are already implemented. The implementation and validation record must identify the equations and controls actually present. Initial values in `Curriculum.swift` must use supported parameter keys, with no silent ignored overrides.

## Source registry

All links below were retrieved on October 13, 2026. Course dates identify the inspected historical syllabus, not a promise about the university's current requirements. Source IDs match `DegreeSource` and lesson `sourceIDs`. Sources support topic selection and equations; the lesson prose, tasks, musical material and project briefs are original.

| ID | Source | Contribution |
|---|---|---|
| `mit-fundamentals` | [MIT 21M.051, Fundamentals of Music, Spring 2007](https://ocw.mit.edu/courses/21m-051-fundamentals-of-music-spring-2007/pages/syllabus/) | Practical foundation linking hearing, rhythm, pitch, notation and harmony |
| `mit-harmony1` | [MIT 21M.301, Harmony and Counterpoint I, Spring 2005](https://ocw.mit.edu/courses/21m-301-harmony-and-counterpoint-i-spring-2005/pages/syllabus/) | Historically situated tonal practice, analysis, composition and performance |
| `mit-harmony2` | [MIT 21M.302, Harmony and Counterpoint II, Spring 2005](https://ocw.mit.edu/courses/21m-302-harmony-and-counterpoint-ii-spring-2005/pages/syllabus/) | Chromatic development, formal transformation and revised compositional work |
| `mit-composition` | [MIT 21M.351, Music Composition, Fall 2008](https://ocw.mit.edu/courses/21m-351-music-composition-fall-2008/pages/syllabus/) | Creation through melodic, contrapuntal, rhythmic and textural problems |
| `mit-world` | [MIT 21M.030, Introduction to World Music, Spring 2013](https://ocw.mit.edu/courses/21m-030-introduction-to-world-music-spring-2013/pages/syllabus/) | Listening in cultural context, interpretation and research writing |
| `illinois-acoustics` | [Illinois PHYS 406 course description, Spring 2017](https://courses.physics.illinois.edu/phys406/sp2017/406pom_course_description.html) | Fusion of musical acoustics, mathematical rigor and experimental projects |
| `illinois-lectures` | [Illinois PHYS 406 lecture map, Spring 2017](https://courses.physics.illinois.edu/phys406/sp2017/406pom_lectures.html) | Vibrations, propagation, interference, instruments and transducers |
| `mit-ode` | [MIT 18.03SC, Differential Equations, Fall 2011](https://ocw.mit.edu/courses/18-03sc-differential-equations-fall-2011/pages/syllabus/syllabus/) | Oscillators, response, Fourier methods, plausibility checks and model interpretation |
| `mit-fourier` | [MIT 18.03 reading and topic map, Spring 2010](https://ocw.mit.edu/courses/18-03-differential-equations-spring-2010/pages/readings/) | Fourier series, periodic input, resonance and convolution |
| `mit-signals` | [MIT 6.003, Signals and Systems, Fall 2011](https://ocw.mit.edu/courses/6-003-signals-and-systems-fall-2011/pages/syllabus/) | Continuous/discrete signals, sampling, spectral representation and system response |
| `mit-production` | [MIT 21M.380, Recording Techniques and Audio Production, Fall 2016](https://ocw.mit.edu/courses/21m-380-music-and-technology-recording-techniques-and-audio-production-fall-2016/pages/syllabus/) | Practical/theoretical audio work and production analysis |
| `mit-production-notes` | [MIT 21M.380 lecture-note map, Fall 2016](https://ocw.mit.edu/courses/21m-380-music-and-technology-recording-techniques-and-audio-production-fall-2016/pages/lecture-notes/) | Acoustics and audio engineering reference paths |
| `openstax-string` | [OpenStax, University Physics 1 §16.3: Wave Speed on a Stretched String](https://openstax.org/books/university-physics-volume-1/pages/16-3-wave-speed-on-a-stretched-string) | Tension, linear density and wave-speed relationship |
| `openstax-standing` | [OpenStax, University Physics 1 §16.6: Standing Waves and Resonance](https://openstax.org/books/university-physics-volume-1/pages/16-6-standing-waves-and-resonance) | Fixed-end standing modes and boundary conditions |
| `openstax-speed` | [OpenStax, University Physics 1 §17.2: Speed of Sound](https://openstax.org/books/university-physics-volume-1/pages/17-2-speed-of-sound) | Frequency, wavelength, propagation and temperature dependence |
| `openstax-intensity` | [OpenStax, University Physics 1 §17.3: Sound Intensity](https://openstax.org/books/university-physics-volume-1/pages/17-3-sound-intensity) | Physical intensity and logarithmic reference levels |
| `openstax-beats` | [OpenStax, University Physics 1 §17.6: Beats](https://openstax.org/books/university-physics-volume-1/pages/17-6-beats) | Interference and simple-tone beat frequency |

No source passages, textbook figures, commercial recordings or university problem sets are bundled. Standard equations and factual relationships are implemented with original explanation and tasks. Source pages retain their own licenses; attribution links do not grant rights to redistribute their assets. The app's musical examples are authored/generated originals.

## Coverage boundaries and validation

The 12-module sequence covers introductory through selected intermediate theory, creation, acoustics and signal mathematics. It does not provide the full breadth/depth of a music degree, a mathematics major or a physics major. Advanced orchestration, formal score engraving, full common-practice harmony, music history, specialized traditions, real instrumental technique, ensemble performance, calibrated psychoacoustics, microphone measurements and complete PDE/DSP analysis need further work.

Validation should check independent analytical identities, units, parameter bounds, deterministic event timing, pitch/ratio conversions, conservation or response limits where applicable, waveform continuity, actual rendered audio samples, lifecycle cancellation, persistence and reproducible exports. A calculation test does not establish audible quality. Simulator stress and real UI interaction precede physical UI automation, following the user's requested order. Device sound, haptic feel, VoiceOver and other accessibility scenarios remain separate evidence categories.

The degree framing is an organizing ambition. Preserve honest labels for practice, prediction, demonstrated calculation, project evidence and reflection. Avoid numerical scores for beauty, authentic culture, musical meaning or universal consonance.
