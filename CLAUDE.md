# Sotto

Whisper messenger for WoW Forever (Interface 16001, 12.1 engine) in the EllesmereUI +
Polestar look. Not a git repository. Author for anything public: creazy231.

- Design: `docs/design.md`; approved look: `docs/mockup/rail-chat-mockup.html` (open it in a
  browser; keep the built window pixel-close to it). Plan and progress: `docs/plan.md`,
  `docs/ledger.md`.
- Offline checks, from this folder, after every change:
  `luajit tests/run.lua && luajit tests/syntax.lua && python3 -I tests/test_media.py`
  (LuaJIT from Homebrew; `tests/fake_wow.lua` is the fake client, `tests/harness.lua` the loader).
- Media: `python3 -I tools/make_media.py .` and `python3 -I tools/make_sound.py .` regenerate
  `Media/` (Pillow, ffmpeg).
- Blizzard's own chat code for this client: github.com/Gethe/wow-ui-source, branch `forever`
  (`Interface/AddOns/Blizzard_ChatFrameBase`). Check hooks against it, not against retail.
- Rules that keep Sotto taint-free:
  - every chat value goes through `ns.IsSecret` before it is compared, indexed, measured or stored;
  - never touch Blizzard's chat edit box in combat or chat lockdown; never write Blizzard's
    last-tell list; only `hooksecurefunc` post-hooks;
  - EllesmereUI only through `EllesmereUI.RegisterSkin` getters (no EUI internals, no `EllesmereUIDB`).
- `docs/` holds the user's screenshot and EllesmereUI's licensed font (mockup assets): never
  ship `docs/` or `tests/` in a public release.
- After a code change: add a `CHANGELOG.md` entry and bump `## Version` in `Sotto.toc`.
