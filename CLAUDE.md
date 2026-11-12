# Sotto

Whisper messenger for WoW Forever (Interface 16001, 12.1 engine) in the EllesmereUI +
Polestar look. Author for anything public: creazy231.

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
  - never touch Blizzard's chat edit box (not even out of combat: closing it from addon code
    taints `ACTIVE_CHAT_EDIT_BOX`); never write Blizzard's last-tell list; only
    `hooksecurefunc` post-hooks;
  - player menus only through `Menu.ModifyMenu`, and there only the Whisper entry's responder
    is swapped (`Core/Intercept.lua`); every other entry stays Blizzard's;
  - EllesmereUI only through `EllesmereUI.RegisterSkin` getters (no EUI internals, no `EllesmereUIDB`).
- `docs/` holds the user's screenshot and EllesmereUI's licensed font (mockup assets): never
  ship `docs/` or `tests/` in a public release.
- Visual check without the game: `luajit tools/render_ui.lua <dir>/chat.html chat` draws what the
  addon built in the fake client as HTML (scenarios: chat, new, lock, empty, settings, toast,
  menu, bn, prompt). The page expects next to it: `media/` (`python3 -I tools/tga2png.py <dir>`),
  `fonts/expressway.ttf`, `fonts/expressway-bold.ttf`, `class/class-<class>.png` and
  `backdrop.jpg` (from `docs/mockup/assets`). Serve the dir over http (fonts need it);
  `?shot=1&scale=2&bg=<image>` frames it for listing screenshots (`docs/listing/`).
- Listing images with their headlines: `python3 -I tools/make_listing.py <dir>` renders every scene
  and shoots all of `docs/listing/screenshots/` with headless Chrome (copy and layout: its `SHOTS`
  list; one idea per headline, one `*accent*` word, `|` breaks a line).
- Git: repo-local identity creazy231 / 13473174+creazy231@users.noreply.github.com, remote
  github.com/creazy231/Sotto (private). Releases: tag → `.github/workflows/release.yml`
  (BigWigs packager); see `docs/RELEASING.md`.
- After a code change: add a `CHANGELOG.md` entry under the next version and tag that version
  to release (`## Version: @project-version@` is filled in by the packager).
