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
Task 8 (in progress): visual verification with tools/render_ui.lua (the addon's real frames drawn as HTML from the fake client) against the mockup — chat, new, lock, empty, settings, toast, menu, bn all match. Real bugs it found, each fixed test-first: a conversation's first message did not set its recency (test_store "a conversation's first message sets its recency…", RED→GREEN); the New divider line had no height (test_ui "divider lines are one pixel high", RED→GREEN); the More menu and settings dropdowns spilled past the window's right edge (test_widgets "a right-aligned menu…", test_ui "the More menu stays inside the window", RED→GREEN). Fake-client gaps fixed (not addon bugs): scroll children anchoring/clipping, natural width of font strings.
Ruling: TOC `## Version: @project-version@` (filled in by the packager from the tag); an unpackaged copy reports "dev" (test_init) — cost if wrong: none.
Ruling: license MIT, © creazy231 — the user did not name one; MIT is the common choice for WoW addons and allows the CurseForge listing — cost if wrong: relicensing later is easy while creazy231 is the only author.
Ruling: personal details (character name, realm) replaced by fictional ones in tests and docs before the first commit, because the repository may become public — cost if wrong: none.
Task 8: complete (final review by a fresh reviewer on HEAD de4b3d9; one fix pass; luajit tests/run.lua → 161 passed, 0 failed; syntax ok; media ok).
Final: fixed reply keys could answer the wrong person or nobody (Critical 1) — test_intercept "the reply keys are bound to Sotto while the setting is on", "in an instance the reply keys stay with Blizzard", "binding changes in combat wait for combat to end", "changed key bindings are picked up", "a typed /r to a stale target prints a notice"; test_ui "the second reply binding opens the last person you whispered" RED→GREEN, suite 161/161
Final: fixed a closed conversation started again stayed closed and the keyboard carried on into another conversation (Critical 2) — test_ui "starting a closed conversation again reopens it", "closing the active conversation releases the compose box" RED→GREEN, suite 161/161
Final: fixed taint from writing Blizzard's chat edit box (Important 3, graded Critical: secret-value errors in Blizzard code) — test_intercept "Sotto never touches Blizzard's chat box"; test_ui "+ starts a conversation in Sotto without Blizzard's chat box" RED→GREEN, suite 161/161
Final: fixed Forever name forms (Important 4) — test_names "the hyphen form is the same person on Forever"; test_contacts "targeting a contact updates level and class" (fake now returns first name + surname); test_engine "the sender's spelling becomes the conversation name" RED→GREEN, suite 161/161
Final: fixed character storage key merged characters sharing a first name (Important 5) — test_db "CharKey is the character's GUID" RED→GREEN, suite 161/161
Final: fixed outgoing whispers and their errors vanished while the window was hidden (Important 6) — test_engine "an outgoing whisper stays in chat while Sotto cannot show it", "an outgoing whisper out of combat opens its conversation in Sotto", "AFK replies stay in chat while Sotto is hidden" RED→GREEN, suite 161/161
Final: fixed opening the window did not mark the conversation read or clear toasts (Important 7) — test_ui "showing the window marks the active conversation read and clears toasts" RED→GREEN, suite 161/161
Final: fixed Enter kept the keyboard (Important 8) — test_ui "Enter releases the keyboard in combat and outside rested areas" RED→GREEN, suite 161/161
Final: fixed minimap button re-shown under EllesmereUI's minimap (Important 9) — test_ui "the minimap button leaves EllesmereUI's hiding alone" RED→GREEN, suite 161/161
Final: fixed roster events refreshing every conversation (Important 10) — test_ui "contact refreshes are batched and skipped while the window is hidden" RED→GREEN, suite 161/161
Final: fixed retention deleting at once and "until logout" wiping on /reload (Important 11) — test_store "history kept until logout is cleared at the next login, not by a reload", "retention changes apply at the next login, not at once" RED→GREEN, suite 161/161
Final: fixed tooltip previews cut UTF-8 characters (minor re-graded Important: the user writes German) — test_ui "tooltip previews never cut a character in half" RED→GREEN (verified the assertion flags 6 broken previews with the old code), suite 161/161
Final: fixed the filter could hide whispers if the UI failed to load (minor re-graded Important: anti-goal "a lost whisper") — test_engine "nothing is hidden from chat until Sotto's window exists" RED→GREEN, suite 161/161
Final: Ruling: /w and "Whisper" in menus no longer open Sotto's box directly; they stay in Blizzard's box and the sent whisper opens the conversation in Sotto — taking over Blizzard's box from addon code taints ACTIVE_CHAT_EDIT_BOX for the session (secret-value errors in Blizzard code with Battle.net whispers and in lockdown) — cost if wrong: one extra step compared with the approved "/w opens it"; the settings copy now says "Use Sotto for replies".
Final: Ruling: the reply keys are override-bound to Sotto only outside instances — inside dungeons/raids whispers are secret and only Blizzard's reply can answer them — cost if wrong: in an instance R opens the normal chat even for a whisper Sotto showed before the pull.
Final: Ruling: after a send the box keeps focus only in rested areas out of combat (reviewer's heuristic) — cost if wrong: in the open world you press the reply key to continue a conversation.
Final: Ruling: English-only copy stands (plan constraint) — cost if wrong: other locales read English.
Final: Ruling: raid-icon codes ({star}) show as text in Sotto — not in the design — cost if wrong: cosmetic.
Final: Ruling: Battle.net whispers whose sender the game hides also stay in normal chat (ledger) — cost if wrong: they show twice.
Final: Ruling: recovered whispers after a fight chime and may open the window — the player wants to see them — cost if wrong: a chime right after the fight.
Final: Ruling: messages count as read while the window is open but faded — cost if wrong: an unread pill missing on a faded window.
Final: Ruling: no confirmation for Clear history / Close conversation (menu actions are deliberate; Close is reversible) — cost if wrong: an accidental Clear history loses that history.
Final: minor (deferred): toast intro slides up and snaps back instead of rising from below.
Final: minor (deferred): Esc with a menu open also closes the window; SottoMenu is a named global.
Final: minor (deferred): copy box hint says Ctrl+C (Cmd+C on a Mac).
Final: minor (deferred): settings control widths are measured once with the load-time font.
Final: minor (deferred): wrapped lines use the default line pitch (mockup 17 px); Battle.net blue is FRIENDS_BNET_NAME_COLOR (#82c5ff) where the mockup used #5ec8ff.
Final: minor (deferred): conv.online is saved, so an old contact can show a green dot until refreshed.
Final: minor (deferred): the "is ignoring you" system pattern never matches (separate event).
Final: minor (deferred): the lockdown banner reads the state during ADDON_RESTRICTION_STATE_CHANGED; re-check a frame later.
Final: minor (deferred): Up arrow replaces the text being typed.
Final: minor (deferred): Battle.net invite uses the bare character name; Ignore has no confirmation.
Final: minor (deferred): whispers another addon's spam filter rejects still appear in Sotto.
Final: minor (deferred): a conversation started with "+" but never used stays in the rail until pruned.
