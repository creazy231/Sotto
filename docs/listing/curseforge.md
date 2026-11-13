# CurseForge listing for Sotto

Everything to paste into the CurseForge project form (authors.curseforge.com).

## Basics

- **Project name:** Sotto
- **Game / class:** World of Warcraft · Addons
- **Game versions:** Retail, Classic Era, Anniversary (TBC), Mists of Pandaria Classic,
  Cataclysm, Wrath, Titan-Reforged and WoW Forever (the packager sets them on every upload
  from the `## Interface` list in `Sotto.toc`)
- **Primary category:** Chat & Communication
- **License:** MIT License
- **Avatar:** `docs/listing/icon-400.png` (square; `icon.png` is the 1024 px original)
- **Summary** (138 characters):

  > Whispers in a calm messenger window: conversations, unread badges and notifications, in the EllesmereUI look. Retail, Classic and Forever.

## Screenshots (gallery, in this order, with these captions)

1. `screenshots/01-conversation.png` — Every whisper, one calm window: conversations in a rail, the chat right beside them.
2. `screenshots/02-new-whisper.png` — See what's new at a glance: unread counts on every badge, a "New" line in the chat.
3. `screenshots/03-notification.png` — Stays out of your fight: in combat a small card slides in instead of the window.
4. `screenshots/04-boss-fight.png` — Boss fight? Nothing gets lost: whispers wait in your chat and land in Sotto when the fight ends.
5. `screenshots/05-settings.png` — Nine settings. That's all.
6. `screenshots/06-empty.png` — Fits right into your UI: EllesmereUI's colours and font, or your class colour.

The images carry their headline; `python3 -I tools/make_listing.py <render-dir>` renders them again
from the addon's real UI (copy and layout in its `SHOTS` list, render dir as in CLAUDE.md).

## Description (Markdown)

```markdown
![Sotto](HERO_IMAGE_URL)

**Whispers in a calm messenger window, drawn in the EllesmereUI look.**
A whisper messenger for World of Warcraft, in the spirit of WIM, with only the options that matter. One download for Retail, every Classic version and WoW Forever.

## Features

- **One window for every whisper.** Character and Battle.net whispers, incoming and outgoing. A slim rail holds one badge per conversation: class icon, unread count, offline contacts greyed out.
- **Reads like a messenger.** Name and time once per run of messages, day separators, a "New" line above what you have not read yet, clickable items, quests and links.
- **Answer where you read.** Enter sends, long messages are split for you, Up and Down bring back what you sent, every conversation keeps its own draft, shift-clicked items land in the box.
- **Stays out of your way.** Out of combat the window opens on a new whisper; in combat a small card slides in instead. No keyboard focus is taken unless you ask for it. The window fades while you are not using it.
- **Your whispers, your window.** Your reply key and "Whisper" in a player menu open Sotto right away, and a whisper you start from the chat box continues there. Whispers are hidden from the normal chat window.
- **Remembers.** Conversations survive reloads and logouts (7, 30 or 90 days, or until logout).
- **Matches your UI.** With EllesmereUI it follows your panel colour, font and accent live; the accent can also be your class colour. Works without EllesmereUI too.
- **Every game version.** Retail, Classic Era, Anniversary, Mists of Pandaria Classic, Cataclysm, Wrath, Titan-Reforged and WoW Forever.

## Boss fights

During boss encounters, Mythic+ and rated PvP the game can hide whisper contents from addons. Sotto tells you so: those whispers stay in your normal chat and arrive in Sotto when the fight ends. Sending pauses meanwhile; your draft waits.

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
