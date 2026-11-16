# v0.2 review at 6462313

2026-11-17 JST. Read README, AGENTS v0.2 and the entire DEV_SPEC v0.2. The simplified approach is accepted for T1-1/T1-2: deterministic caches, fixed style prompt, external DSP, built-in model allowlist, and Mac-to-iPhone screening. No checkpoint framework or signing infrastructure is requested.

Remaining findings (before their respective tickets):

- **P1 / T2-7 / §7 line 370:** Two new run requests can both await the same old task. After that await, each must recheck ownership/reservation before launching. Increment/claim the request generation before suspension; stale waiters must exit. Test three concurrent calls, not just two. Keep activeTask/runID; no extra persistence state machine needed.
- **P1 / T1-4 / §12 line 501:** Forcing endMs=startMs+1 can exceed the clip boundary or overlap the next cue after rounding. Example: clip end 15.0000, cue [14.9996,15.0000) rounds to [15000,15000), then becomes [15000,15001). Define a bounded quantization policy before subtitle implementation (skip/report cues with no representable interval, or move start earlier within bounds).
- **P1 / S0-2, T2-8 / §8 line 392:** Compiling into modelID/version/osBuild is valid, but Whisper's expected encoder basename/location still needs an adapter or an explicit runtime path. Verify actual Core ML loading on Mac/iPhone; do not accept silent CPU fallback as successful integration.
- **P2 / T2-6 / §7 line 349:** Adjacent DTW words may have equal timestamps. min(nextWordStart,start+maxWordDuration) then gives zero duration. Define merging/estimation and decoded-end clamping, and test repeated/equal timestamps before ASR integration.
- **P2 / T2-7 / §7 line 375:** Include flashAttention when DTW is disabled, and an adapter/preprocessing version in deterministic ASR keys. Canonical key serialization and atomic validated ASR file publication must match vocals handling. This preserves the lightweight file-cache design.
- **P2 / S0-3 / §7 line 337:** External DSP is a sound conversion boundary. Freeze STFT centering/scaling, frequency-bin handling, and mask normalization against the actual chosen TF checkpoint. The OLA identity test alone does not verify model equivalence.
- **P2 / T3-7 / §10 line 463:** The rate-scaled latency formula is a starting hypothesis. Validate the chosen node clock, TimePitch latency, route latency and seeks on device; a test of the same algebra does not prove acoustic accuracy.
- **P2 / T4-1 / §11 line 478:** The v0.1 template JSON was removed but v0.2 refers to it. Restore the schema or pin the original source at 5fd54b5 before implementing templates.
- **Evidence wording / §2, §8, §9:** 4 GB is a target, not a proven safe lower bound; allowlists do not guarantee "absolute compliance"; isolated local research still requires permission for the exact weights/use. No Demucs model is used in this work.

T1-2 implementation resolutions (no product scope change): ASRLanguage/ASRWord are pure shared values in LCCore, avoiding Project → Apple transcription dependency. Validated model properties are immutable; editors construct validated replacements. A project with unsupported schema is rejected; no undocumented older schema is guessed. Nested model decoding invokes the same validation as initialization. Actual filesystem containment/symlink checks belong to ProjectStore, beyond the lexical relative-path validation here.

T1-1's macOS xcodebuild acceptance remains pending; this cloud delivery only proves the Linux portion. No Xcode project, model or actual inference is claimed.
