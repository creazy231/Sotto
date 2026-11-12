# Sotto Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build Sotto, a WIM-like whisper messenger for WoW Forever with the approved Rail + chat window in the EllesmereUI + Polestar look.

**Architecture:** Plain Lua addon, no libraries. `Core/` holds logic that never touches frames (testable offline): settings, colour maths, names, text formatting, the conversation store, contact info, the chat engine and the whisper interception. `UI/` draws everything with our own frames and textures; EllesmereUI is read only through `EllesmereUI.RegisterSkin` getters. Modules talk through `ns` tables and a small message bus (`ns.Fire` / `ns.Listen`).

**Tech Stack:** WoW Lua 5.1 (Interface 16001), LuaJIT 2.1 for offline tests, Python 3 + Pillow + ffmpeg for media.

**Spec:** `docs/design.md`; visual reference `docs/mockup/rail-chat-mockup.html`.

Execution: native (the user is away and asked for no interaction). Not a git repository: no commit steps; every task ends with the full offline suite passing.

## Global Constraints

- TOC: `## Interface: 16001`, `## SavedVariables: SottoDB`, `## OptionalDeps: EllesmereUI`, `## Author: creazy231`.
- Globals: only `SottoDB`, `SLASH_SOTTO1`, `SlashCmdList.SOTTO`, `BINDING_*_SOTTO*`, `Sotto_OnAddonCompartment*`, `Sotto_Binding*`, named frames `SottoWindow`, `SottoMinimapButton`, `SottoCopyBox`.
- Every chat value is checked with `ns.IsSecret` before it is compared, indexed, measured or stored.
- No `OnUpdate` while idle; tweens and tickers run only while something is moving or the window is shown.
- Copy is English, sentence case, as in the mockup; strings live in `ns.L`.
- Palette, sizes and copy follow the mockup: window 410×306, rail 46, header 46, badge tile 28, compose box 26 high.

## Review Focus

1. Forever names with spaces and different case ("ayla brightwind" vs "Ayla Brightwind") must land in one conversation and be sent with the exact spelling → `test_names.lua: same key for case and own-realm variants`, `test_engine.lua: whisper from "ayla brightwind" joins "Ayla Brightwind"`.
2. Secret arguments must never raise and the whisper must stay in normal chat → `test_engine.lua: secret whisper in lockdown is queued and not filtered`, `secret whisper outside lockdown is ignored`.
3. Messages over 255 bytes with item links and umlauts → `test_format.lua: split keeps links whole`, `split never cuts a UTF-8 character`.
4. A whisper in combat must not open the window or take focus → `test_engine.lua: in combat with openOn=nocombat a toast is requested, no focus`.
5. The reply key when Blizzard's last tell target is stale or empty → `test_intercept.lua: ReplyTell opens Sotto's last incoming conversation`.

---

### Task 1: Scaffold, harness and core utilities

**Files:**
- Create: `Sotto.toc`, `Core/Init.lua`, `Core/DB.lua`, `Core/Color.lua`
- Create: `tests/harness.lua`, `tests/run.lua`, `tests/syntax.lua`, `tests/test_load.lua`, `tests/test_db.lua`, `tests/test_color.lua`
- Create: `CLAUDE.md` (dev conventions, test command), `CHANGELOG.md`

**Interfaces:**
- Produces: `ns.L`, `ns.IsSecret(...) -> bool`, `ns.InLockdown() -> bool`, `ns.Safe(fn, ...)`, `ns.On(event, fn)`, `ns.Off(event, fn)`, `ns.Listen(msg, fn)`, `ns.Fire(msg, ...)`, `ns.After(sec, fn)`, `ns.Print(text)`;
  `ns.Get(key) -> value`, `ns.Set(key, value)` (fires `"SETTING_CHANGED", key, value`), `ns.CharKey() -> "Name-Realm"`, `ns.DB` (= `SottoDB` after `ADDON_LOADED`);
  `ns.Color.Shift(c, dL, k) -> {r,g,b,a}`, `ns.Color.Contrast(c1, c2) -> number`, `ns.Color.Lift(ground, toward, c, ratio) -> r,g,b`.
- Settings defaults: `openOn="nocombat"`, `sound="chime"`, `hideInChat=true`, `intercept=true`, `accent="class"`, `fontSize=13`, `fadeIdle=true`, `keepDays=30`, `minimap=true`.

- [ ] Write `tests/harness.lua`: fresh fake environment per test (frames with scripts and points, textures, font strings with deterministic metrics: width = 0.5 × size × chars, height = ceil(width / box width) lines × (size + 2)), edit boxes, events (`T.fire(event, ...)`), timers (`T.flush()` runs `C_Timer.After` callbacks), `hooksecurefunc`, secret values (`T.secret(v)` + `issecretvalue`/`hasanysecretvalues`/`canaccessvalue`), `C_ChatInfo`, `C_BattleNet`, `C_FriendList`, `ChatFrameUtil`, `InCombatLockdown` toggle; `T.loadAddon()` reads `Sotto.toc` and runs each file with `(ADDON, ns)`.
- [ ] `test_load.lua: every TOC file loads without error; only the allowed globals are created`.
- [ ] `test_db.lua: defaults fill a fresh SottoDB; Set fires SETTING_CHANGED; unknown keys in an old DB survive`.
- [ ] `test_color.lua: Shift(#141414, 0.02) ≈ #191919; Contrast(white, black) = 21; Lift(#191919, text, shaman #0070de) reaches 4.5`.
- [ ] Implement until `luajit tests/run.lua` and `luajit tests/syntax.lua` pass.

### Task 2: Names and text formatting

**Files:** Create `Core/Names.lua`, `Core/Format.lua`, `tests/test_names.lua`, `tests/test_format.lua`

**Interfaces:**
- Produces: `ns.Names.Key(name) -> string`, `ns.Names.Short(name) -> string` (first word, realm dropped), `ns.Names.Display(name) -> string` (own realm dropped);
  `ns.Format.Split(text, limit) -> {chunks}`, `ns.Format.Linkify(text) -> text` (URLs become `|Hsotto:url:<url>|h<url>|h`), `ns.Format.Time(t) -> "14:02"`, `ns.Format.Day(t, now) -> "Today"|"Yesterday"|weekday|"Nov 10"`, `ns.Format.Plain(text) -> text` (codes stripped, link text kept).

- [ ] `test_names.lua: same key for "Ayla Brightwind", "ayla brightwind", "Ayla Brightwind-<own realm>"; Short("Ayla Brightwind") = "Ayla"; Short("Bob-Other") = "Bob"`.
- [ ] `test_format.lua: split keeps links whole; split never cuts a UTF-8 character; split prefers spaces; text under the limit is one chunk; Linkify wraps http(s) and www. URLs but not existing |H links and strips trailing ")." punctuation; Day boundaries`.
- [ ] Implement until the suite passes.

### Task 3: Conversation store and contacts

**Files:** Create `Core/Store.lua`, `Core/Contacts.lua`, `tests/test_store.lua`, `tests/test_contacts.lua`

**Interfaces:**
- Conversation: `{ key, kind="w"|"bn", name, tag, bnID, class, race, level, zone, guid, online, last, unread, open, msgs={ {t, d="i"|"o"|"s", m, s} } }`.
- Produces: `ns.Store.Ensure(kind, name, extra) -> conv, isNew`, `ns.Store.Get(key)`, `ns.Store.Add(conv, d, text, t, sys) -> msg`, `ns.Store.MarkRead(conv)`, `ns.Store.MarkUnread(conv)`, `ns.Store.List() -> {conv...}` (open, newest first), `ns.Store.Close(conv)`, `ns.Store.Clear(conv)`, `ns.Store.UnreadTotal()`, `ns.Store.Prune(days)`; messages `"CONV_UPDATED"`, `"MESSAGE_ADDED"`, `"UNREAD_CHANGED"`.
  `ns.Contacts.Learn(conv, guid)`, `ns.Contacts.Refresh(conv)`, `ns.Contacts.Meta(conv) -> {strings}`, `ns.Contacts.Color(conv) -> r,g,b`, `ns.Contacts.Icon(conv) -> path, l, r, t, b | nil`, `ns.Contacts.Initials(conv) -> "AL"`.

- [ ] `test_store.lua: character conversations live under the character, Battle.net ones are shared; 400-message cap; Prune drops old messages and empty closed conversations; List order; unread totals`.
- [ ] `test_contacts.lua: GUID gives class and race; friends list gives level and zone; Meta order "34", "Orc Warrior", "Desolace"; offline contact meta says offline; secret values are ignored`.
- [ ] Implement until the suite passes.

### Task 4: Chat engine

**Files:** Create `Core/Engine.lua`, `tests/test_engine.lua`

**Interfaces:**
- Consumes: Store, Contacts, Names, Format, settings.
- Produces: `ns.Engine.Filter(frame, event, ...) -> bool`, `ns.Engine.Send(conv, text) -> bool`, `ns.Engine.LastIncoming() -> conv`, `ns.Engine.LastOutgoing() -> conv`, `ns.Engine.Locked() -> bool`; messages `"INCOMING", conv, msg, opened`, `"LOCKDOWN_CHANGED", locked`; `ns.Engine.wantOpen` hook used by UI (`ns.UI.Open(conv, opts)` when present).

- [ ] `test_engine.lua: whisper creates a conversation and an incoming message; inform adds outgoing; whisper from "ayla brightwind" joins "Ayla Brightwind"; filter hides handled whispers only when hideInChat; GM whispers and letterbox lines are left alone; secret whisper in lockdown is queued and not filtered; queued whisper is recovered once after the lockdown with its original time; secret whisper outside lockdown is ignored; in combat with openOn=nocombat a toast is requested, no focus; Send splits long text and is refused in lockdown; AFK/DND and "player not found" become system lines; sound respects the setting and the 2 s cool-down`.
- [ ] Implement until the suite passes.

### Task 5: Whisper interception

**Files:** Create `Core/Intercept.lua`, `tests/test_intercept.lua`

**Interfaces:**
- Consumes: `ChatFrameUtil.ActivateChat`, edit box `UpdateHeader`/`GetAttribute`, `ChatFrameUtil.ReplyTell`/`ReplyTell2`, `ns.UI.Open(conv, {focus=true, text=...})`.
- Produces: `ns.Intercept.Init()`, `ns.Intercept.HookEditBox(editBox)`.

- [ ] `test_intercept.lua: a whisper header opens Sotto one frame later and closes the chat box; typed text is carried over; nothing happens in combat, in lockdown, with a secret target or with intercept off; ReplyTell opens Sotto's last incoming conversation; ReplyTell2 its last outgoing one; a BN header opens the Battle.net conversation`.
- [ ] Implement until the suite passes.

### Task 6: Theme and widgets

**Files:** Create `Core/Theme.lua`, `UI/Widgets.lua`, `tests/test_theme.lua`, `tests/test_widgets.lua`; generate `Media/` with `tools/make_media.py` and `tools/make_sound.py`

**Interfaces:**
- Produces: `ns.Theme.Color(name) -> r,g,b,a`, `ns.Theme.Accent() -> r,g,b`, `ns.Theme.ClassColor(file) -> r,g,b`, `ns.Theme.Font(role) -> path, size, flags`, `ns.Theme.Refresh()` (fires `"LOOKS_CHANGED"`);
  `ns.W.Fill(parent, color, layer, sub)`, `ns.W.Hair(parent, edge)`, `ns.W.Text(parent, role, color)`, `ns.W.Icon(parent, name, size, color)`, `ns.W.IconButton(parent, icon, tip, onClick)`, `ns.W.Pill(parent, h)`, `ns.W.Switch(parent, get, set)`, `ns.W.Segmented(parent, choices, get, set)`, `ns.W.Dropdown(parent, choices, get, set)`, `ns.W.Slider(parent, lo, hi, step, get, set)`, `ns.W.Menu(anchor, items)`, `ns.W.Tip(owner, title, lines)`, `ns.W.Shadow(frame)`, `ns.W.Paint(obj, fn)` (re-runs on `LOOKS_CHANGED`).

- [ ] `test_theme.lua: without EllesmereUI the palette matches the mockup tokens; with a fake EllesmereUI skin S the panel colour, font and accent follow S; accent "class" uses the lifted class colour; OnLooksChanged repaints`.
- [ ] `test_widgets.lua: switch toggles and repaints; segmented selects; slider clamps and steps; dropdown opens a menu and sets the value`.
- [ ] Generate media; check `Media/` files exist and are valid TGA/OGG (`python3 -I tests/test_media.py`).
- [ ] Implement until the suite passes.

### Task 7: Window, rail, log, compose, settings, toasts, launcher

**Files:** Create `UI/CopyBox.lua`, `UI/Rail.lua`, `UI/Log.lua`, `UI/Compose.lua`, `UI/Settings.lua`, `UI/Toast.lua`, `UI/Window.lua`, `UI/Launcher.lua`, `Bindings.xml`, `tests/test_ui.lua`

**Interfaces:**
- Produces: `ns.UI.Open(conv, opts)`, `ns.UI.Toggle()`, `ns.UI.Hide()`, `ns.UI.ShowSettings()`, `ns.UI.Active() -> conv`, `ns.UI.IsShown()`, `ns.UI.Typing(conv) -> bool`; `ns.Toast.Show(conv, msg)`; `ns.CopyBox.Show(title, text)`; bindings `SOTTO_TOGGLE`, `SOTTO_REPLY`, `SOTTO_NEXT`.

- [ ] `test_ui.lua: window builds hidden with the saved size; opening a conversation selects it, clears unread and fills the header; rail shows one badge per open conversation with unread pills; log groups runs within 5 minutes and adds day separators and the New divider; Enter in the compose box sends and Up recalls; lockdown shows the banner and pauses sending; settings rows change settings; toast click opens and focuses; minimap button shows the unread total; Esc handling; WIM notice when WIM is loaded`.
- [ ] Implement until the suite passes.

### Task 8: Review and polish

- [ ] Fresh-eyes review of the whole addon against `docs/design.md` and the mockup (subagent, model with the best judgement), focused on taint, secrets and visual fidelity.
- [ ] Fix findings; full suite green; `CHANGELOG.md` 1.0.0; README for players.
