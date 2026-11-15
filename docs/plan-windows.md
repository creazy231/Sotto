# Separate windows — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans (the user is away and asked for no
> interaction; executed natively, TDD, mutation checks). Steps use checkbox (`- [ ]`) syntax.

**Goal:** an option, off by default, that gives every conversation its own window, as WIM does: the window's
"–" minimises it, shift-click closes it and deletes its history.

**Architecture:** the chat column (header, notices, log, compose box, "Whisper to" prompt) becomes a reusable
`Pane`; `Log` and `Compose` become instances. The window keeps one pane; `UI/Windows.lua` makes one framed
pane per conversation. With the option on, the window itself becomes a slim dock (the rail alone), the home of
minimised conversations; its gear still opens the settings at full size.

**Tech Stack:** WoW Lua 5.1, LuaJIT offline tests (`tests/fake_wow.lua`), Pillow for the new glyph.

**Spec:** `docs/design.md`, section "Separate windows (2026-11-15)".

## Global Constraints

- Off by default (`settings.separate = false`); with it off nothing changes: all 232 tests stay green and the
  renders of every scene (`tools/render_ui.lua`: chat, new, lock, empty, settings, toast, menu, bn, prompt)
  stay the same.
- The approved look: a separate window is the chat column of the approved window (header 46, compose 42,
  same fills, hairlines, fonts), plus the rail's 28 px class tile at the left of its header.
- Taint rules of `CLAUDE.md` unchanged: never Blizzard's chat box, only post-hooks, EllesmereUI only through
  RegisterSkin getters, every chat value through `ns.IsSecret`.
- Every frame of Sotto's on UIParent takes the Scale setting (`W.Scaled`, offsets divided by `W.Scale()`).
- New globals: only the windows' frame names `SottoConv<n>` (UISpecialFrames needs names).
- No work every frame while idle.

## Review Focus

1. Shift-click on "–" must delete the history and never just hide; a plain click must never delete →
   tests "shift-click closes …", "the dash minimises …".
2. A whisper to a minimised conversation must count as unread and reopen per "Open the window" →
   "a minimised conversation counts unread …".
3. The reply key after a conversation was closed and forgotten must open that person again, not someone else →
   "the reply key after closing …".
4. Switching the option with conversations on screen must lose no draft and leave no orphan window →
   "turning separate windows on/off …".
5. Scale and saved places: a window keeps its bottom-left corner at any scale; a closed one forgets its place.

---

### Task 1: Log instances (refactor)
- [x] `ns.Log.New(frame) -> log` (`frame, content, items, rows, conv`; `:SetConv(conv, firstUnread)`,
  `:Refresh(remeasure)`, `:Render()`, `:OnMessage(conv)`, `:Scroll(d)`, `:ScrollToBottom()`, `:Clear()`).
  Heights cache shared; LOOKS_CHANGED refreshes every log.
- [x] Window uses `UI.log`; tests read `ns.UI.log`. Suite green, renders identical.

### Task 2: Compose instances (refactor)
- [x] `ns.Compose.New(frame) -> compose` (`box, placeholder, conv`; `:SetConv, :SaveDraft, :SetText, :Focus,
  :HasFocus, :UpdatePlaceholder`); drafts and sent history shared; `ns.Compose.Focused()`,
  `ns.Compose.DropDraft(key)`; one InsertLink hook for the focused box; Tab → `ns.UI.SelectNext(conv)`;
  `COMPOSE_FOCUS(focused, compose)`.
- [x] Window uses `UI.compose`; tests read `ns.UI.compose`. Suite green, renders identical.

### Task 3: Pane and Fader (refactor)
- [x] `ns.Pane.New(frame, opts)` (opts: `tile`, `button` "close"|"minimise", `onButton(pane, mouse)`,
  `promptParent`, `onPick(pane, name)`, `move` {start, stop}); `:SetConv(conv)` (New line at the first unread,
  marks read, refreshes the contact), `:UpdateHeader()`, `:Layout()`, `:ShowPrompt()`, `:ClosePrompt()`,
  `:MoreMenu(anchor)`, `:Invite()`; WIM notice and lockdown banner for every pane; `ns.Pane.ProperName`.
- [x] `W.Fader(frame, awake) -> fader` (`:Wake()`), the window's idle fade moved onto it.
- [x] `UI.header/notice/banner/prompt/log/compose` stay. Suite green, renders identical.

### Task 4: Setting, Forget, glyph
- [x] Tests: "Separate windows is off by default and is the first row under Look";
  "Forget empties and closes a conversation and its saved place". `settings.separate`; Settings row
  (switch, "Each conversation in its own window, as in WIM"); `Store.Forget(conv)`; `Media/Icons/minimise`.

### Task 5: The separate windows
- [x] Tests (test_windows.lua): a whisper opens its own window, not the rail window, no focus; two
  conversations two windows; a minimised conversation counts unread and opens again with the next whisper; the
  dash minimises and keeps history; shift-click closes and deletes history and draft; the button turns into a
  red cross while shift is held; the "…" menu closes and deletes; a toast opens the window focused; the reply
  key, a player menu's Whisper and a whisper sent from chat open the window; the reply key after closing opens
  that person again; typing mutes the chime; Tab moves to the next window; Esc minimises every window.
- [x] `UI/Windows.lua`; `UI.Open/Sees/IsShown/OnScreen/Typing` dispatch; Engine and Contacts through them.

### Task 6: Places
- [x] Tests: the first window opens where the chat column would be, at its size; the next ones cascade; a
  moved or resized window keeps its place for its conversation (saved); a closed one forgets it; Scale keeps
  each window's corner.

### Task 7: The dock
- [x] Tests: with the option on the window is the rail alone, as tall as its conversations; a badge opens its
  conversation's window and shows which are open; shift-click on a badge closes and deletes; the gear opens the
  settings at full size, closing them docks again; "+" opens a window asking for a name (Enter binds it, a known
  name brings its window, Esc lets it go); toggling and the minimap button show and hide the dock.

### Task 8: Switching and the rest
- [x] Tests: on with a conversation shown moves it into its own window; off closes the windows and the window
  shows the last one used; drafts survive both; the gamepad interface hides the windows; the lockdown banner and
  the WIM notice show in each window; a window on screen lets the filter hide "not found" lines.

### Task 9: Docs, preview, review
- [x] design.md, CHANGELOG (1.4.0, unreleased), README, listing copy, CLAUDE.md, ledger; render scenes
  `windows` and `dock`; a fresh-eyes review; fixes; commit (no push, no tag).

Done 2026-11-15 (see docs/ledger.md, "Separate windows"): tasks 1–9, then a review round
(2 Important, 6 Minor findings, all fixed with tests). 307 tests.
