# Sotto — design

Approved 2026-11-12 (layout and look by the user; everything after "go with that" decided
autonomously while the user was away, see "My calls").

## Intent

A whisper messenger for World of Warcraft: Forever that works like WIM (whispers open in
their own window, you answer there) but with only the options that matter, drawn in the
user's EllesmereUI look composed the way Polestar draws its "EllesmereUI" scheme. It
replaces WIM 3.19.5 + EllesmereSkin_WIM 1.3.0. Design is the user's top priority: the
built window must stay pixel-close to the approved mockup
(`docs/mockup/rail-chat-mockup.html`).

## Goals

- Character whispers and Battle.net whispers, incoming and outgoing, in one window.
- **Rail + chat layout** (picked by the user from three sketches):
  - a 46 px rail on the left: the mark on top, one 28 px badge per conversation (class
    icon, Battle.net initials), unread count pill, accent bar on the active one, offline
    contacts greyed out, "+" (new conversation) and the gear at the bottom; a click opens a
    badge's conversation, the right button its menu, shift-click or the middle button
    closes it (shift-click added at the user's request, 2026-11-14);
  - the chat column: a header (online dot, name in class colour, "level · race class ·
    zone", invite, "…" menu, close), the message log, the compose box.
- Grouped message log: name and time once per run of messages, day separators, a "New"
  divider, clickable links (items, quests, spells, players, URLs → copy box), system lines
  (AFK, DND, offline, not found).
- Compose box: Enter sends (long text split into 255-byte messages without breaking
  links), Up/Down recalls sent lines, Esc leaves the box, shift-clicked links go in.
- When a whisper arrives: the conversation goes to the top of the rail; the window opens
  (Always / Out of combat / Never); if it doesn't, a notification card slides in above the
  chat; a sound plays; the whisper is hidden from the normal chat window.
- When the player starts a whisper (`/w`, the reply key, "Whisper" in menus) Sotto opens
  the conversation instead of the chat box, when that is safe.
- Boss fights / chat lockdown: an amber notice; whispers stay in normal chat and are
  brought into Sotto when the lockdown ends, where the game allows it.
- History survives reloads and logouts (30 days by default).
- In-window settings (gear), launcher (minimap button with unread count, addon compartment,
  `/sotto`, key bindings).
- Follows EllesmereUI live (panel colour, accent, font) through its documented skinning
  API; looks right without EllesmereUI too.

## Non-goals

- Channel, guild, party or raid chat windows (WIM's chat module).
- Emoticons, RP profiles, spam filters, a history browser, skins, Edit Mode integration,
  `/who` lookups. (A window per conversation was one too, until the user asked for it on
  2026-11-15: "Separate windows" below.)

## Anti-goals (failure even if it "works")

- Taint: an "Interface action failed" or a secret-value error inside Blizzard code caused by
  Sotto.
- A lost whisper: anything Sotto cannot show must stay visible in the normal chat.
- Stealing keyboard focus when a whisper arrives (the player may be running with WASD).
- Work every frame while idle.

## Constraints

- Built on WoW Forever (game type camelot, 12.1 engine), Lua 5.1. Since 2026-11-13 one TOC
  loads on every client: `## Interface: 120105, 120107, 50504, 40402, 38002, 30405, 20506,
  16001, 11509` (Retail 12.1.5 and its 12.1.7 test realm, Mists, Cataclysm, Titan-Reforged,
  Wrath, TBC Anniversary, Forever, Classic Era; warcraft.wiki.gg/wiki/TOC_format). Retail
  loads only an exact match: every client patch needs its new number and a release.
- Other clients, checked against wow-ui-source (branches `live` 12.1.5, `classic` 5.5.4,
  `classic_anniversary` 2.5.6, `classic_era` 1.15.9, `classic_titan` 3.80.2, `forever`
  1.60.1; 2026-11-13): all run the same Blizzard_ChatFrameBase (ChatFrameUtil, the filter
  registry with `ProcessMessageEventFilters`, filters before `SetLastTellTarget`),
  Blizzard_Menu (`Menu.ModifyMenu`, `MenuUtil.GetElementText`), UnitPopupShared
  (`UnitPopupMenus`, `GetFullPlayerName`, `MENU_UNIT_*` tags), C_ChatInfo (lockdown and
  chat-line APIs), C_BattleNet and every event Sotto registers. Forever-only: surnames
  (`RegionalUniqueNamesEnabled`; elsewhere names are "Name-Realm", which `Names` handles)
  and title friends (`C_BattleNet.GetDefaultTitleWhisperTarget`, already optional). The
  addon compartment exists on Retail and Forever only (the TOC fields are ignored
  elsewhere); class icons fall back from the `classicon-*` atlases to the class sheet.
  So no code path changes per client; `tests/test_flavors.lua` plays a Retail/Classic client.
- Secret values: during chat messaging lockdown (encounters, Mythic+, PvP and
  communication-restricted maps) whisper text and senders are secret. Blizzard only calls
  message filters when every argument is accessible (`ChatFrameFilters.lua`, `canaccessvalue`).
  Addon sends are blocked in lockdown.
- Forever character names are two words without a realm ("Ayla Brightwind").
- Blizzard's chat handler (`Mainline/ChatFrameOverrides.lua`, forever branch 1.60.1) runs the
  filters first: a whisper an addon hides never reaches `SetLastTellTarget`, the
  `TELL_MESSAGE` sound or `FlashClientIcon`. Sotto must do all three jobs itself.
- No in-game testing for the builder: offline LuaJIT tests against a fake API, then the
  user's `/reload`.

## Approaches

UI (the user picked): **Rail + chat** over "Tabs + chat" (cramped past ~5 conversations) and
"classic WIM windows" (most clutter and options).

Build: **a standalone addon** that draws its own frames and reads EllesmereUI's accent,
panel colour and font through `EllesmereUI.RegisterSkin` (Polestar's approach), over
reskinning WIM further (keeps WIM's options and complexity) or forking WIM (huge, GPL).

## Decisions made with the user

- Name: **Sotto** (from *sotto voce*), checked free on CurseForge, Wago, WoWInterface and
  GitHub on 2026-11-12. Parley, Hush, Susurrus and Murmory are taken by whisper addons.
- Layout: Rail + chat. Look: the mockup as shown, grouped messages, accent = class colour
  with EllesmereUI's accent as a setting.

## My calls (autonomous, user away)

- **Palette:** Polestar's "EllesmereUI" scheme rebuilt from EllesmereUI's panel colour
  (#141414 @ 92 %): sidebar −0.03, footer −0.02, panel +0.02, panelAlt +0.055,
  sky +0.09 OKLab lightness; text #f8f8f8 / #cacccf / #a2a5a9; hairlines white 10 %,
  hover 7 %, selected 11 %. Contact and accent colours lifted to 4.5:1 on the panel.
- **Fonts:** EllesmereUI's font, no outline, 1 px shadow; names in "Expressway Bold" when
  the EUI font is Expressway (falls back to the regular font). Without EUI: the game font.
- **Settings (12):** Open the window (Always / Out of combat / Never), Sound (Soft chime /
  Game whisper / None), Hide whispers from the chat window, Use Sotto to whisper, Separate
  windows (2026-11-15), Keep windows open (2026-11-22), Accent (Class colour /
  EllesmereUI), Scale (50–200 %), Text size (11–16), Fade when idle, Remember
  conversations (Until logout / 7 / 30 / 90 days), Minimap button.
- **Scale** (2026-11-14, the user's request): 50 to 200 % in steps of 5, default 100 %, for
  everything Sotto draws on UIParent: the window, its menu, the notifications and the copy
  box (not the minimap button, which follows the minimap). The window's bottom-left corner
  stays put (its position is saved in UIParent's units, the anchor's offsets divided by the
  scale); the notifications stack up from that corner at the same scale. The slider sits in
  the window it scales, so a knob dragged with the mouse held applies when it is let go (the
  window would otherwise grow under the cursor); the wheel applies at once. A new scale
  repaints everything, so every hairline stays one physical pixel. Its track lines up with
  Text size's (the same room for the value). `/sotto reset` resets position and size, not
  the scale.
- **Timestamps** are not a setting: the time sits next to each name.
- **No auto-focus** on incoming whispers; focus only when the player asked (reply key,
  click on a notification, `/w`, clicking the box).
- **Lockdown sending:** the box says "Paused for the fight · your draft waits here" and keeps
  the draft (the mockup's "Enter hands it to your chat" was dropped: putting text into
  Blizzard's chat box from addon code in combat risks taint).
- **Reply keys (revised after the final review):** Sotto never writes to Blizzard's chat
  edit box or its last-tell list. Closing or refocusing that box from addon code leaves
  `ACTIVE_CHAT_EDIT_BOX` tainted, after which Blizzard's chat code runs tainted and errors on
  the secret names of Battle.net whispers and chat lockdown. Instead, while "Use Sotto to
  whisper" is on, the player's own REPLY/REPLY2 keys are override-bound to Sotto's
  bindings (set out of combat, outside instances). `/w` stays with Blizzard's box; the
  sent whisper opens its conversation in Sotto. A typed `/r` that would answer a stale
  target prints a notice (read-only post-hook on `ProcessChatType`).
- **"Whisper" in player menus (added after the user asked for WIM's behaviour):** opens the
  conversation in Sotto with the cursor in the box, without opening Blizzard's box at all.
  `Menu.ModifyMenu` on every `MENU_UNIT_*` tag swaps only the Whisper entry's responder
  (found by its text, `WHISPER`, also inside the Interact submenu); every other entry stays
  Blizzard's, and the menu system keeps an addon responder from tainting its neighbours.
  The name is Blizzard's own (`UnitPopupSharedUtil.GetFullPlayerName`). Battle.net friends
  get their Battle.net conversation (the account id counts as Blizzard counts it: from a
  Battle.net name link, in chat or on EllesmereUI's friends list, it arrives as text), except those WoW Forever whispers by character
  (`C_BattleNet.GetDefaultTitleWhisperTarget`, which Blizzard's `SendBNetTell` follows):
  they get that character's conversation, as their replies come from the character. The
  class comes from the unit or, for a
  name clicked in chat, from that chat line when it is theirs. Left alone with the setting
  off, inside instances, in chat lockdown and for secret names.
- **The group finder's whisper entries (added 2026-11-14, after the user found that a whisper
  from the group finder opened Blizzard's box first):** open Sotto the same way, under the
  same conditions. The premade groups (Blizzard_GroupFinder: Retail and the Classic
  clients) tag their menus, so `Menu.ModifyMenu` reaches them: `MENU_LFG_FRAME_SEARCH_ENTRY`
  ("Whisper Leader"; the title is the group's name, the leader comes from
  `C_LFGList.GetSearchResultInfo(owner.resultID)`) and `MENU_LFG_FRAME_MEMBER_APPLY`
  ("Whisper"; `C_LFGList.GetApplicantMemberInfo(owner:GetParent().applicantID,
  owner.memberIdx)`). The Classic-style browser (Blizzard_GroupFinder_VanillaStyle, WoW
  Forever's and the Classic clients'; it loads on demand) builds a listing's menu without a
  tag and without an owner of its own: it names `LFGBrowseFrame.SearchEntryDropDown`, which
  no branch has any more, so the menu belongs to the top-level parent. A right-click on a
  listing runs `LFGBrowseFrame:CreateSearchEntryMenu(entry)`; the menu it builds passes
  `Menu.PopulateDescription`, as every menu does (that is where the ModifyMenu callbacks
  run). A `hooksecurefunc` post-hook there keeps the last menu built, and one on
  `CreateSearchEntryMenu` (hooked when the browser loads, or at login if it came first)
  takes it when its title is the listing's leader (`C_LFGList.GetSearchResultInfo(
  entry.resultID).leaderName`, the name Blizzard titles it with and its "Send Message"
  whispers). The open menu's own proxy is no use here: only live and forever give it
  `EnumerateElementDescriptions`. Blizzard's menu calls every responder through
  `securecallfunction`, so this one is as isolated as a ModifyMenu one. Buttons that whisper
  (the browser's and the friends list's Send Message, a name left-clicked in chat) stay
  Blizzard's: its code opens the chat box before an addon's can run, and closing the box
  from addon code is the taint above.
- **New conversation ("+"):** Sotto's own name field over the header ("Whisper to"); the
  spelling comes from a known conversation, the friends list or the guild, else each word
  is capitalised. Blizzard's chat box is never opened from Sotto.
- **Keyboard after sending:** kept in rested areas out of combat, released elsewhere (the
  reply key brings it back).
- **Recovery after lockdown:** queue `{event, lineID, time}` only while
  `C_ChatInfo.InChatMessagingLockdown()` is true; when the chat restriction ends, rebuild
  text, sender and GUID with `C_ChatInfo.GetChatLineText/SenderName/SenderGUID(lineID)`.
  Unrecoverable lines are dropped quietly (they are already in normal chat). Secret
  messages outside lockdown (possible for Battle.net senders on 12.1) are left to normal
  chat and not queued.
- **GM whispers** (`arg6 == "GM"`) and letterbox lines (`arg16`) are left to Blizzard.
- **History model:** account-wide `SottoDB`; character conversations under the logged-in
  character, Battle.net conversations shared by all characters (keyed by BattleTag when it
  is readable). At most 400 messages per conversation; pruned by age at login.
- **Contact info** from the whisper's GUID (`GetPlayerInfoByGUID`), the friends list, the
  guild roster, the group, target and mouseover, and Battle.net game account info; never
  `/who`.
- **Toasts:** shown only when a whisper does not open the window; one card per
  conversation (a "+N" counter instead of stacking), at most three, 8 s, hover pauses,
  click opens and focuses, right-click dismisses. They stack upward from the window's
  bottom-left corner.
- **Sound:** a soft two-note chime synthesised for Sotto (`Media/Sounds/chime.ogg`), 2 s
  cool-down, silent while the player is typing in that conversation; FlashClientIcon on
  every incoming whisper.
- **Launcher:** a round minimap button (EllesmereUI's minimap collects named minimap
  buttons into its flyout), the addon compartment entry, `/sotto` (`/sotto settings`,
  `/sotto reset`), key bindings Toggle / Reply to last whisper / Next unread.
- **WIM:** when WIM is loaded Sotto shows a notice with "Turn off WIM" (disables WIM and
  EllesmereSkin_WIM, then offers a reload). Sotto keeps working either way.
- **whisperMode:** when the game is set to open whispers in new tabs, the settings show a
  one-click switch to "In-line".
- **Esc** clears the compose box's focus first. With "Keep windows open" off it then closes
  the window (UISpecialFrames); on (the default since 2026-11-22) it leaves the window
  alone, see "Keep windows open" below.
- **WoW Forever's gamepad interface** (2026-11-14, the user's request; 1.1.0): Sotto steps
  aside while it is on. Why: the controller cannot reach an addon's window there (Forever's
  only pointer, the soft cursor, serves the map and the colour picker; Blizzard's gamepad
  navigation, SmartNavigation, refuses frames from addon code: `EnsureIsSecure`,
  `SecureHelper:WrapFunction`), while the game's own chat is made for the controller
  (`FloatingChatFrame` gamepad focus and prompts). Real gamepad support would need a
  controller layer of Sotto's own (button input, focus ring, legend, an open binding, as
  NaowhForever's `GamepadNav.lua` does) and typing would still need a keyboard; not built.
  - `ns.Gamepad()` (Core/Init.lua) is Blizzard's own test (`InputUtil.IsGamepadUIEnabled`:
    `C_InputInterfaceStyle.GetCurrentStyle() == Enum.InputDeviceInterfaceType.Gamepad`),
    live; false where the client lacks it (Retail, Classic). `GAMEPAD_CHANGED(on)` comes a
    frame after `INPUT_DEVICE_INTERFACE_TRANSITION` (the style reads right only then).
  - Then: the chat filter hides nothing, so the chat window shows every whisper and plays
    its own sound and flash; Sotto stores a copy, never as unread; no window, notification
    or "continue in Sotto" for a whisper sent from the chat box; the reply keys, the
    menus' Whisper entry and a typed `/r` are Blizzard's (no override, no swap, no notice).
  - The switch to that interface closes the window and the notifications; the way back
    changes nothing on screen. By hand (`/sotto`, the minimap button, the compartment) the
    window still opens. Settings show a row at the top ("Gamepad interface style"), and the
    whisper-tab hint stays hidden there.

## Separate windows (2026-11-15)

The user's words: "an option inside settings to have (just like WIM) every whisper in its own
windows. off by default. these windows then could be minimized or with shift click closed
(then no history is stored / history gets deleted)". Built while the user was away; every
call below is mine.

WIM, read from its source (3.19.5, `Sources/WindowHandler.lua`): a click on a window's close
button hides it to the minimap icon (the conversation stays), shift-click destroys it (its
lines are gone); the button's glyph turns from "hide" to "close" while shift is held
(EllesmereSkin_WIM draws them as a bar and a red cross); Esc hides every window; the minimap
icon lists the conversations.

- **Setting:** Look → "Separate windows" (a switch, off), first in that section: "Each
  conversation in its own window, as in WIM". Eleven settings.
- **A conversation's window** is the chat column of the approved window, unchanged (header,
  notices, log, compose box), plus the rail's 28 px class tile at the left of its header
  (the window has no rail beside it). Its last header button is "–": a click minimises the
  window, shift-click closes the conversation and deletes its history, its draft and its saved
  place. While shift is held over it, it turns into a red cross and its tooltip says so.
  The "…" menu's last entry, "Close and delete history", does the same.
- **Minimised** = hidden, the conversation kept (WIM's hide): its badge stays in the dock,
  a whisper counts unread there and on the minimap button, and opens the window again as
  "Open the window" says (Always / Out of combat / Never; else the notification card).
- **The dock:** with the option on, the window is the rail alone (46 px wide, as tall as its
  conversations, at most the window's height, growing upwards from its saved corner): the
  mark (drag), a badge per conversation (open windows carry the accent bar), "+" and the gear.
  The minimap button, `/sotto`, the compartment and the Toggle key show and hide it, as they
  did the window. A badge's click opens its window, shift-click or the middle button closes
  and deletes, the right button gives Open, Clear history, Close and delete history. The gear
  opens the settings at the window's full size; their close docks again. "+" opens a new
  window with the "Whisper to" field over its header; Enter makes it that conversation's
  window (or brings the window it already has), Esc lets it go.
- **Places:** the first window opens where the chat column of the window would be, at its
  size; the next ones step 26 px right and down from there (the first free step). A window
  the player moved or resized keeps that place for its conversation, saved with it
  (`conv.win`: corner in UIParent's units, size in its own), so it comes back there; a closed
  conversation forgets it. Scale works as for the window: the corner stays put.
- **Everything else follows the conversation's window:** the reply keys, "Whisper" in menus,
  the group finder, a whisper sent from chat and a notification's click open or focus it; a
  shown window counts as read; typing in it mutes the chime for it; Tab moves to the next open
  window; with "Keep windows open" off Esc minimises every window (WIM's escape); the
  gamepad interface hides them; the lockdown banner and the WIM notice show in each.
- **Switching:** on: a conversation shown in the window moves into its own window at the
  same place, the window docks. Off: the separate windows close and the window shows the one
  used last. Drafts are per conversation either way.
- **Closing keeps meaning what it meant in the rail window** (hidden from the rail, history
  kept until "Remember conversations" drops it); only separate windows delete on close, as
  the user asked. A closed conversation stays known by name (empty), so the reply key opens
  that person again and not someone else.
- **After the fresh-eyes review (same day):**
  - *Seen* means on screen and not covered: a window counts as read while no window brought
    up after it lies over a quarter of it or more. A whisper to a covered window brings it to
    the front (read), unless the player is typing in another window or "Open the window" says
    no (combat, Never): then it counts unread and a card shows. Clicking, dragging or typing
    in a window brings it up and reads it; one that comes back into view is read. (Since
    2026-11-22 a faded window's whispers wait for a look: "Unread while faded".)
  - While the player types in one window, a whisper for another never opens a window over
    the box: a card instead, as in combat.
  - The cards stack up from above the window's place (the windows open over its corner),
    as many as fit below the top of the screen, else down from below it.
  - The server's copy of a line sent from a Sotto box (an echo) opens nothing; one that
    arrives after its conversation was closed for good stays out of it (the chat window
    keeps it). The rail window had the first half too: closing it right after sending no
    longer brings it back.
  - A minimised window gives its frame back to the pool (frames stay as many as windows on
    screen at once); a moved one comes back at its saved place, else at the first free step.
  - Turned on in the settings, the conversation shown before them gets its own window when
    the settings close (not if the window was closed meanwhile).
  - The "+" window moves by its name field, and its message box waits for the name.
  - A conversation closed while the settings are open no longer throws them away on the
    next whisper (the rail window did that too).

## Keep windows open (2026-11-22)

The user's words: "in the options there should be a way (on by default) to keep the chat
window or windows permanently open. Reducing the opacity after a while, as now, is good,
but closing completely is not nice. With every chat in its own window it should also be
possible for the bar with all the chat tabs to stay permanently." Built while the user was
away; every call below is mine.

What closed the window: it was one of the game's special frames (UISpecialFrames), and
Blizzard's CloseAllWindows hides them all, not only on Esc but on every loading screen
(`PLAYER_ENTERING_WORLD`), on death, when the player loses control (fear, stun), when a
full-screen panel opens and when UIParent shows again after Alt+Z
(Blizzard_UIParentPanelManager, Blizzard_Game; forever branch 1.60.1). WIM's own
"Escape Hides Windows" (on by default) adds and removes its windows from that list the same
way.

- **Setting:** Look → "Keep windows open" (a switch, on), right under "Separate windows":
  "Esc and loading screens leave them open, and they come back after a reload". Twelve
  settings.
- **On:** Sotto's windows (the window or dock, and every separate window) are not special
  frames (`W.Escapable`), so nothing but the player closes them; the idle fade stays as it
  was. Menus and the copy box stay special frames (Esc still closes them). Esc in a box
  still only leaves the box.
- **Off:** as before: Esc and the rest close the window and minimise the separate windows.
- **Back after a reload or login:** what was on screen at logout (`PLAYER_LOGOUT`) comes back
  at the session's first loading screen, after the login's pruning: the window on the
  conversation it showed (`SottoDB.window.shown`, `.conv`), or with separate windows the dock
  and every shown window in its place, in its order (`conv.up = { n, x, y }`, kept per
  conversation, so another character's conversations keep theirs and Battle.net ones are
  shared). A place the player chose (`conv.win`) still wins; a remembered one is not saved as
  theirs. Closed or minimised windows stay so; a conversation pruned or closed meanwhile does
  not come back. Later loading screens bring nothing back.
- **The dock is the player's:** shown and hidden only by hand (the minimap button, `/sotto`,
  the Toggle key, the compartment), and with the setting on it stays until they hide it,
  across reloads. A window opening does not bring the dock (a dock that keeps coming back
  after being hidden would be the opposite of what was asked).
- **The gamepad interface** still hides everything (the controller cannot reach it); with the
  setting on, the way back shows again what it hid, and a logout or login in that interface
  keeps it for when mouse and keyboard are back.
- **After the fresh-eyes review (same day):** a window that comes back covered keeps what it
  had unread (opening reads a window); a remembered place taken meanwhile (a window opened by
  hand in the gamepad interface) gives way to the next free step; turning "Separate windows" on
  or off while the gamepad interface holds the windows brings them back the new way (the
  window's conversation in its own window, or the window on the separate window that was in
  front); a gamepad interface the client reports only after the first loading screen keeps
  what the login was to bring back.
- **Left as it was:** a whisper to a window that is open on another conversation lights the
  window up and counts unread in the rail, as before; it does not switch the conversation
  (a whisper shown for a moment in an idle window and then replaced would count as read
  unseen). Whispers into a conversation that is on screen counted as read even while the
  window was faded; the user then chose to change that ("Unread while faded" below).

## Checked against WIM 3.19.8 (2026-11-22)

Read from WIM 3.19.8 (installed, 2026-11-20): its options (`Sources/Options/ModernOptions.lua`),
`Modules/ClickControl.lua`, `Modules/Expose.lua`, `Modules/ShortcutBar.lua`, `Sources/WindowHandler.lua`
and its changelog. Built from it:

- **A click into the game world gives the keyboard back** (WIM's "Click to Release Focus", on
  by default there): a short click (0.25 s or less, WIM's limit is 0.2 s) with any button on
  the world frame lets go of a box of Sotto's (compose boxes, name fields; `W.ReleasedByWorld`),
  so the movement keys move the character again; the box keeps its text. A click held longer
  steers and keeps the box, and so does one tapped while the other button is held (WIM's
  `buttonCount < 2`). Unlike WIM, in combat too (clicking the world then means fighting).
  Other addons' boxes are left alone. No setting. On WoW Forever and Retail the game itself
  already lets go of any box on a plain left mouse-down outside it (Blizzard_Game Mainline
  `ClearCurrentKeyboardFocus`, which Forever runs too), so there this adds the right and
  middle buttons; on clients without that it does all of it.
- **Online and offline lines** (WIM 3.19.8 routes these notices into the player's window): a
  friend who comes online or goes offline while their conversation is on screen gets a line
  there ("Tarin came online"; Battle.net friends from their toast, named by their account
  name when no BattleTag is readable; a friend Forever whispers by character in that
  character's conversation, found by the character Forever named for them last this session,
  as it names none once they are offline); the same notice again within a minute adds
  nothing. The line leaves the rail's order alone (`Store.Add`'s `keepOrder`). The chat window
  keeps its own notice (Sotto hides no friend notices).

Offered to the user: hiding the windows in combat (WIM's "Expose", on by default there; with
permanent windows it would come and go with every pull), whispers into a faded window
counting unread until the player looks, a growing multi-line box, names suggested while
typing in "Whisper to", a list of earlier conversations, "Invite to guild" in the "…" menu.
The user picked the unread rule and "Invite to guild" (built below) and wants to test 1.5.0
in game before it is released. Still non-goals: emoticons, RP profiles, whisper filters, a
history browser, skins, channel windows, `/who` lookups.

## Unread while faded, Invite to guild (2026-11-22, the user's pick)

- **A whisper counts as read only while someone is at its window:** its conversation on
  screen (shown, the chat view, not covered) and the window not idle, that is the mouse over
  it, the keyboard in its box or a menu of Sotto's open within the last 4 s (the fade's own
  timer), or the player just brought it up (the reply key, a /w, a badge, a card, the
  minimap button: `fader:Wake()`). A whisper's own light-up is `fader:Flash()` and leaves
  the window idle, so a second whisper during it is unseen too. With "Fade when idle" off
  nothing changes (`ns.UI.Reads`, `ns.Windows.Reads`).
- **What came in unseen is read by a look at that window:** the mouse over it or its
  keyboard (`W.Fader`'s `look`); not a menu open elsewhere, not the dock, not a window
  another lies over. A click on its badge, its card or into it reads it as before.
- **Its badge, the minimap button and the New line show it:** the New line moves above the
  first unseen whisper and stays once read, as for a conversation opened unread; scrolled
  back, the view keeps its place.
- **Separate windows:** a whisper that brings a covered window to the front while nobody is
  at it leaves it unread (it still comes up); one that comes back into view while faded waits
  for a look too.
- **The empty window** (no conversation) takes up a whisper as before; idle, it stays unread.
- **Unchanged:** online and offline lines still go into a faded window (on screen is on
  screen); a window opened for a whisper (it was hidden or minimised) reads it as before.
- **"Invite to guild"** in the "…" menu after "Add friend": shown while the player may invite
  (`CanGuildInvite`) and the contact is a character not in the guild yet
  (`C_GuildInfo.MemberExistsByName`): a character conversation, or a Battle.net friend as the
  character they play; `C_GuildInfo.Invite`, in every client (checked in wow-ui-source: live,
  classic, classic_era, classic_anniversary, classic_titan, forever).
- **After the fresh-eyes review (same day):**
  - *A Battle.net friend's character is invited only when this game can reach it*, as
    Blizzard's friends list decides it (Camelot `FriendsFrame.lua`): the same version of the
    game (`wowProjectID`), realm info, on Classic the same realm; on Retail another realm
    adds "-Realm"; WoW Forever's names are unique without one (`conv.invite`, set by
    `Contacts`). Before, a friend playing Classic as "Robin" got "Robin" invited here, maybe a
    stranger. The header's group invite had the same flaw and follows the same rule now.
  - *The player at a window* is the mouse over it with nothing lying on top there
    (`W.MouseIn`: the topmost frame under the cursor is the window's own; a frame the game
    keeps from addons counts as something else), over its own menu, or its keyboard (the box
    or the "Whisper to" field). A menu open from another window neither reads a window nor
    keeps it lit; a menu left open with nobody at it no longer keeps every whisper read.
  - *Nobody can see a hidden interface* (Alt+Z): a whisper then counts unread.
  - *The New line goes with its message*, not its place: the oldest messages go at 400, and
    Clear history no longer leaves a line behind.
  - *Alt+Z no longer minimises separate windows*: WoW hides UIParent's children with it
    (OnHide while their own shown flag stays on); a window hidden that way comes back with
    the interface.
  - *Left as it is:* scrolled back, a New line that moves from above the view to a newer
    whisper shifts the view by its own height (rare, a look only).

## Left to the builder

Exact pixel offsets inside rows; animation curves; pool sizes; how many lines the mouse
wheel scrolls; the order of the "…" menu entries.
- **Checked against WIM 3.19.6 (after the Battle.net menu fixes):** Sotto now also
  - recovers Battle.net whispers from a chat lockdown: the account id is secret then and no
    chat line keeps it, so it comes back from the line's account name
    (`BNet_GetBNetIDAccount`, or the friend list for a friend who logged off meanwhile);
  - shows `CHAT_MSG_BN_WHISPER_PLAYER_OFFLINE` (a Battle.net whisper to an offline friend) in
    that conversation and marks it offline; hidden from chat only while Sotto is shown;
  - files every Battle.net whisper of a friend Forever whispers by character
    (`Contacts.TitleTarget`) under that character, like the menu and Blizzard's `SendBNetTell`;
  - runs other addons' chat filters through Blizzard's registry
    (`ChatFrameUtil.ProcessMessageEventFilters` on a hidden message frame of Sotto's, never a
    chat tab, Sotto's own filter stepping aside): what
    they hide (spam filters; LayerSwap's line for its own undeliverable addon message) stays
    out of Sotto. Not while WIM still runs: its filter hides every whisper it shows;
  - on `PLAYER_REPORT_SUBMITTED` drops the reported player's whispers (own lines stay), as
    Blizzard's chat removes their lines; a conversation left empty leaves the rail.
  Left as is: censored lines (the event's text is what Blizzard shows; not verifiable
  offline), AFK/DND as reply target (Blizzard does not do it either), WIM's 800-character
  Battle.net split (Sotto splits at 255; harmless).
