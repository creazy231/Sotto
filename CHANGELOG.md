# Changelog

## 1.4.0 (unreleased)

- Separate windows (Settings, Look; off unless you turn it on): every conversation in its
  own window, as in WIM. Each window is the chat you know, with the contact's class icon
  in its header. Its "–" minimises it; shift-click it, and it turns into a red cross,
  to close the conversation and delete its history. Windows open where the chat used to
  be and step down from there; one you move or resize keeps that place for its
  conversation, also after a reload.
- With separate windows on, the window itself becomes a slim dock: the rail with every
  conversation (open windows carry the accent bar, minimised ones their unread count),
  "+" to start one and the gear for the settings. The minimap button, `/sotto` and the
  Toggle key show and hide it.
- A whisper to a window hidden behind another brings it to the front. While you type in
  one window, or in combat, a notification card shows instead, so nothing covers the box
  you type in. The cards stay clear of the windows.
- Closing the window right after sending no longer brings it back when the server echoes
  your line, and the settings no longer jump back to the chat when a conversation is
  closed while they are open.

## 1.3.0

- The group finder's whisper entries now open Sotto right away, as "Whisper" in a player
  menu does, instead of the chat box first: "Send Message" on a listing in the group
  browser (WoW Forever and the Classic clients), "Whisper Leader" on a premade group and
  "Whisper" on someone who applied to your group.
- Shift-click a conversation in the rail to close it (the middle mouse button still does
  too).

## 1.2.0

- Scale in the settings (Look): 50 to 200 %, for the window, its menus, the notifications
  and the copy box. The window keeps its bottom-left corner where it is, and the
  notifications stay at that corner. Dragging the slider applies the new scale when you let
  go of the mouse; the mouse wheel changes it in steps of 5 %.

## 1.1.0

- WoW Forever's gamepad interface: Sotto now steps aside while it is on. Your whispers
  stay in the game's own chat, which is made for the controller: it shows them, plays its
  sound, and your reply keys and "Whisper" in player menus answer there. Sotto opens no
  window and no notification then (switching to the gamepad interface closes them) and
  quietly keeps a copy of your whispers, so your conversations are complete when you are
  back on mouse and keyboard. The window still opens by hand, and its settings say so at
  the top.

## 1.0.0

First release.

- Whispers and Battle.net whispers in one window: a rail of conversations (class icon,
  unread count, offline contacts greyed out) and the chat on the right.
- Grouped messages with day separators and a "New" line, clickable items, quests and
  links (links open a copy box), AFK, DND and "player not found" lines.
- Compose box: Enter sends and splits long messages, Up and Down recall what you sent,
  drafts per conversation, shift-clicked items go in.
- Your reply keys and "Whisper" in player menus open Sotto right away (outside instances),
  and whispers you start from the chat box continue in Sotto. Sotto never touches the
  game's own chat box.
- Out of combat the window opens on a new whisper; in combat a notification card slides
  in instead. A soft chime, the game's whisper sound, or none.
- Boss fights and other chat lockdowns: whispers stay in your normal chat and arrive in
  Sotto afterwards; sending pauses and your draft waits.
- History kept for 7, 30 or 90 days, or until logout.
- In-window settings, a minimap button with the unread count, `/sotto`, key bindings
  (including "whisper the last person you whispered").
- Follows EllesmereUI's panel colour, font and accent live; class colour accent by
  default.
- Battle.net friends: whispers from a boss fight arrive afterwards too, a whisper to an
  offline friend says so, and friends WoW Forever whispers by character keep one
  conversation.
- What another addon hides from the chat window (a spam filter, for example) stays out of
  Sotto too; reporting a player removes their whispers, as the chat window does.
- Offers to turn off WIM so whispers do not arrive twice.
- One download for Retail, every Classic version (Classic Era, Anniversary, Mists of
  Pandaria, Cataclysm, Wrath, Titan-Reforged) and WoW Forever.
