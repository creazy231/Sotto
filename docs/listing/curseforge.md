# CurseForge listing for Sotto

Everything to paste into the CurseForge project form (authors.curseforge.com).

## Basics

- **Project name:** Sotto
- **Game / class:** World of Warcraft · Addons
- **Game version:** WoW Forever (the packager sets it on every upload from `## Interface: 16001`)
- **Primary category:** Chat & Communication
- **License:** MIT License
- **Avatar:** `docs/listing/icon-400.png` (square; `icon.png` is the 1024 px original)
- **Summary** (130 characters):

  > Whispers in a calm messenger window: conversations, unread badges and notifications, drawn in the EllesmereUI look. For WoW Forever.

## Screenshots (gallery, in this order, with these captions)

1. `screenshots/01-conversation.png` — One window for every whisper: a rail of conversations, the chat on the right.
2. `screenshots/02-new-whisper.png` — Unread badges, a "New" line, and links you can click.
3. `screenshots/03-notification.png` — In combat a small card slides in instead of the window.
4. `screenshots/04-boss-fight.png` — Boss fights: whispers wait in your chat and arrive afterwards.
5. `screenshots/05-settings.png` — Nine settings, right in the window.
6. `screenshots/06-empty.png` — A calm start.

## Description (Markdown)

```markdown
![Sotto](HERO_IMAGE_URL)

**Whispers in a calm messenger window, drawn in the EllesmereUI look.**
A whisper messenger for World of Warcraft: Forever, in the spirit of WIM, with only the options that matter.

## Features

- **One window for every whisper.** Character and Battle.net whispers, incoming and outgoing. A slim rail holds one badge per conversation: class icon, unread count, offline contacts greyed out.
- **Reads like a messenger.** Name and time once per run of messages, day separators, a "New" line above what you have not read yet, clickable items, quests and links.
- **Answer where you read.** Enter sends, long messages are split for you, Up and Down bring back what you sent, every conversation keeps its own draft, shift-clicked items land in the box.
- **Stays out of your way.** Out of combat the window opens on a new whisper; in combat a small card slides in instead. No keyboard focus is taken unless you ask for it. The window fades while you are not using it.
- **Your whispers, your window.** Your reply key and "Whisper" in a player menu open Sotto right away, and a whisper you start from the chat box continues there. Whispers are hidden from the normal chat window.
- **Remembers.** Conversations survive reloads and logouts (7, 30 or 90 days, or until logout).
- **Matches your UI.** With EllesmereUI it follows your panel colour, font and accent live; the accent can also be your class colour. Works without EllesmereUI too.

## Boss fights

The 12.x engine hides whisper contents from addons during boss encounters, Mythic+ and rated PvP. Sotto tells you so: those whispers stay in your normal chat and arrive in Sotto when the fight ends. Sending pauses meanwhile; your draft waits.

## Commands

- `/sotto` open or close the window
- `/sotto settings` settings
- `/sotto reset` put the window back

Key bindings under Key Bindings > AddOns > Sotto: show or hide, reply to the last whisper, whisper the last person you whispered, next unread conversation. With "Use Sotto to whisper" on, your normal reply keys and "Whisper" in player menus open Sotto too (inside dungeons and raids they stay with the normal chat, because the game hides whispers from addons there). The minimap button and the addon compartment open it too.

## Coming from WIM?

Sotto notices WIM and offers to turn it off, so whispers do not arrive twice.
```

`HERO_IMAGE_URL`: upload `screenshots/hero.png` to the project's images (or use the first
gallery image) and paste its URL.
