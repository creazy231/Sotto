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
    contacts greyed out, "+" (new conversation) and the gear at the bottom;
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
- Emoticons, RP profiles, spam filters, a history browser, multiple windows, skins,
  Edit Mode integration, `/who` lookups.

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
- **Settings (10):** Open the window (Always / Out of combat / Never), Sound (Soft chime /
  Game whisper / None), Hide whispers from the chat window, Use Sotto to whisper, Accent (Class colour / EllesmereUI), Scale (50–200 %), Text size (11–16), Fade when idle,
  Remember conversations (Until logout / 7 / 30 / 90 days), Minimap button.
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
- **Esc** closes the window (UISpecialFrames) unless the compose box has focus, which Esc
  clears first.
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
