# SDD ledger — plan: Sotto/docs/plan.md

Spec: Sotto/docs/design.md (reachable). Executor: native, inline (user away).

Ruling: no git repository and no worktree — the ledger lives here and every task ends with the full offline suite (`luajit tests/run.lua && luajit tests/syntax.lua`) instead of a commit — cost if wrong: no per-task diff history; the user can still diff against nothing (new folder).

Pre-flight:
- Task 1 → all: `ns.On/Listen/Fire/Get/Set/IsSecret` used everywhere; names fixed in plan Task 1. OK.
- Task 3 (Store) → Task 4 (Engine): `Store.Ensure(kind, name, extra)`, `Store.Add(conv, d, text, t, sys)`. OK.
- Task 4 (Engine) → Task 5 (Intercept): `Engine.LastIncoming()/LastOutgoing()` return conversations; Intercept opens them through `ns.UI.Open`. OK.
- Task 5/4 → Task 7 (UI): `ns.UI.Open(conv, {focus, text})` is produced by Task 7 but consumed earlier; Core code calls it only when present (`if ns.UI and ns.UI.Open`). Ruling: Core never requires UI at load — Core tests run without UI files — cost if wrong: none, UI loads after Core in the TOC.
Task 1: complete (tests: luajit tests/run.lua → 20 passed, 0 failed; luajit tests/syntax.lua → syntax ok). Ruling: added tests/test_init.lua for the Init helpers (plan named only load/db/color) — cost if wrong: none.
Task 2: complete (tests: luajit tests/run.lua → 38 passed, 0 failed; syntax ok).
Task 3: complete (tests: luajit tests/run.lua → 62 passed, 0 failed; syntax ok). Ruling: conv.last starts at creation time and never moves back for older (recovered) messages; two store tests used 1970 timestamps and were corrected — cost if wrong: none.
Task 4: complete (tests: luajit tests/run.lua → 84 passed, 0 failed; syntax ok). Ruling: Sotto plays its sound and flashes the client icon only when hideInChat is on and the whisper had no secret arguments; otherwise Blizzard showed the line and already played TELL_MESSAGE — cost if wrong: a silent whisper when the player removed whispers from every chat tab and the line carried a secret value. Ruling: messages are stored raw and linkified when drawn — cost if wrong: none.
Task 5: complete (tests: luajit tests/run.lua → 96 passed, 0 failed; syntax ok). Ruling: interception acts one frame after Blizzard's call and the reply keys always use Sotto's own last incoming/outgoing conversation (newest on record after a reload) — cost if wrong: a one-frame flash of the Blizzard chat box. Ruling: closing Blizzard's box falls back to Hide when its escape handler errors — cost if wrong: none.
Task 6: complete (tests: luajit tests/run.lua → 113 passed, 0 failed; syntax ok; python3 -I tests/test_media.py → media ok). Ruling: Theme loads after Format (it sets Format.linkColor) — TOC order changed from the plan — cost if wrong: none.
Task 7: complete (tests: luajit tests/run.lua → 140 passed, 0 failed; syntax ok; media ok). Ruling: conversations touched in the same second sort by an in-memory touch order (not saved) — cost if wrong: none. Ruling: UI.Open ignores a non-table second argument (Store.Ensure returns two values) — cost if wrong: none. Ruling: the settings view close (x) goes back to the conversations instead of hiding the window — cost if wrong: one extra click. Ruling: "+" opens Blizzard's chat box with "/w " so Blizzard's name completion picks the name and interception hands it to Sotto — cost if wrong: with "Use this window for /w" off, "+" just starts a normal whisper.
