# REFACTOR-03: physical performance move, 0.0.371

This is an intermediate increment of draft PR21, based on exact370
`9a2ad81fb77282c4f52261e694653b28b21f01b8`, source-reviewed independently in
review5690964419 and accepted by Team Lead. It does not complete REFACTOR-03.
The final parent CI receipt is retained separately in baseline; it is not CI for371.

The approved map moves33 source files and14 tracked UID into `tools/qa/performance`.
Four ignored local UID follow their sources. Four public facades remain, including
module identity and mutable SAMPLER for the frozen redraw consumer. The protected
sampler and UID stay byte-exact. Root source count changes314→285, still above≤30.
54 live Python consumers import the single canonical implementation; old standalone
commands retain source-bound bootstrap access. Runtime, artwork, budgets and prior
evidence are unchanged. Other six task cards and the separate plan07 are excluded.

FROZEN logical keys and archive destinations stay unchanged. Fresh collection reads
only the two known canonical inputs, marks `qa-performance-v1`, and launches the
canonical capture. Readers bind this closed layout to its URI; missing metadata means
the original URI, unknown metadata is denied. No arbitrary metadata source path or
re-signing of old evidence is introduced. Eight new tests include actual Git/file I/O,
archive corruption/overwrite denials, a real fake-open child argv witness, legacy/current
launch mismatch, headless denial and module identity. Fake child evidence is not GPU/FPS.

`before-profile.json` records12 real commands at370 before moving; `after-profile.json`
records the final comparable run with all old113 and new8 tests. Both use temporary
HOME/XDG and external copies for generated summaries,14 actual SIGKILL workers and
headless main smoke180. Their semantic outputs and immutable input JSON hashes must
match. `extra-profile.json` records a fresh headless editor import, all18 canonical GD
parses and54 real consumer imports (53direct root CLI/1canonical launcher) from foreign cwd/Git. No game window/new FPS
admission is claimed. General Game/normal/F10 evidence is recorded only by actual gates.

The first profile stopped at after-16.txt on a nested `performance_protocol` import.
Its path was corrected without changing assertions. The second old34-case run then
found its old string mock-target; nested-target-attempt02.txt and after-attempt02-16.txt
retain that failure. The target was moved to the same canonical PLAN module, preserving
all mutations and assertions. Source capsules/plan attempts are retained. Subsequent
green runs, complete gates and source freeze determine acceptance, never these failed
attempts. The first two full after attempts each preserve their14 real workers/smoke.

Every task still requires its own independent exact-head review, Team Lead decision,
successful CI and final approved merge. Full03 remains draft/in_progress with no
Task-Complete. The autonomous queue stays03→07→06→first overworld throughVMAP003.

The initial consumer harness omitted the script directory normally added by direct CLI;
extra-020.txt retains that error. The corrected root53 contexts passed. The existing
canonical context test additionally needs its actual launcher prepare_imports;
consumer-036.txt retains that harness-only failure. consumer-profile.py resumes the
remaining19 contexts, with no product changes or repeated18GD parse. All54 final
consumer outcomes are exact file/process imports, no Game/FPS admission.
Parent370 CI completed8/8 success, including both full test jobs; diagnostics are in
baseline/ci370-final.json. Reviewer execution boundaries remain those of review5690964419.

The first full architecture gate (gates-01) stopped at the actual frozen causal/redraw
protocol import. Three live frozen consumers require the public performance_protocol
name, including protocol-before-gate order; one self-contained fixed-gate snapshot
keeps its own archived protocol. A fourth small public facade is documented in
compatibility-exception.json, without rewriting the initial map or frozen evidence.
Historical final-root forecast10 becomes11; final budget remains<=30. The corrected
8-case sourcef5225782… gives controlled red1fail/1error→green8/0 and the old frozen
observer suite6/0. The first new regression mistakenly expected the self-contained
snapshot to use the project protocol: frozen-graph-green-attempt01.txt and
after-attempt04-19.txt retain this harness-only failure and its source capsule.
The final profile is attempt5 and authoritative full gates are gates-02; all earlier
attempts are retained and do not substitute for those results.

The first corrected frozen-import run generated a Python .pyc in the self-contained
snapshot directory. Scope auditing rejected that untracked cache before gates-02;
scope-attempt02.txt and bytecode-cleanup.json preserve the cause/digest. The generated
cache alone was removed; the final test adds only PYTHONDONTWRITEBYTECODE=1 for child
imports, leaving all assertions unchanged. Final sourcef5225782… independently repeats
red1fail/1error→green8/0. Profile5 already passed all19 commands and compared implementation
outputs; its8-case test differs only by this later bytecode-prevention environment flag.
The complete gates-02 rerun exercises the final test source and every mandatory suite.
