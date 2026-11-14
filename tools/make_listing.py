#!/usr/bin/env python3
"""Sotto dev tool: renders the CurseForge gallery from the addon's real UI.

    python3 -I tools/make_listing.py <render-dir>

Run from the addon folder. <render-dir> holds what tools/render_ui.lua pages
need (see CLAUDE.md): media/, fonts/expressway.ttf, fonts/expressway-bold.ttf,
class/, icon.png and the backdrops named in SHOTS. Every scene is rendered
fresh with luajit, served over http (the fonts need it) and shot with headless
Chrome into docs/listing/screenshots/.

Copy follows the listing rules: one idea per headline, short words, one word
in the accent (*word*), | breaks a line.
"""
import functools
import http.server
import os
import subprocess
import sys
import threading
import urllib.parse

CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
OUT = os.path.join("docs", "listing", "screenshots")

# name, scene (tools/render_ui.lua), shot parameters
SHOTS = [
    ("01-conversation", "chat", dict(
        bg="bg-sunset.jpg", layout="left", eyebrow="Whisper messenger",
        title="Every whisper,|one *calm* window.",
        sub="Conversations sit in a rail,|the chat right beside them.")),
    ("02-new-whisper", "new", dict(
        bg="bg-canyon.jpg", layout="right", eyebrow="Unread",
        title="See what's *new*|at a glance.",
        sub="Unread counts on every badge,|a New line in the chat.")),
    ("03-notification", "toast", dict(
        bg="bg-sunset.jpg", layout="top", focus="toast", scale="3", ty="230", cy="745", eyebrow="In combat",
        title="Stays out of|your *fight*.",
        sub="A small card slides in instead of the window.")),
    ("04-boss-fight", "lock", dict(
        bg="bg-canyon.jpg", layout="left", eyebrow="Raids and dungeons",
        title="Boss fight?|*Nothing* gets lost.",
        sub="Whispers wait in your chat|and land here when the fight ends.")),
    ("05-settings", "settings", dict(
        bg="bg-sunset.jpg", layout="right", eyebrow="Settings",
        title="*Ten* settings.|That's all.",
        sub="Only what matters,|right inside the window.")),
    ("06-empty", "empty", dict(
        bg="bg-canyon.jpg", layout="left", eyebrow="Made for WoW Forever",
        title="Fits right|into your *UI*.",
        sub="Follows EllesmereUI's colours and font,|or your class colour.",
        pills="Battle.net whispers,Reply keys,Drafts per chat,Clickable links,90 days of history,Minimap button")),
    ("hero", "chat", dict(
        bg="bg-sunset.jpg", layout="left", hero="1", scale="1.45", w="1920", h="640", cx="1380", cy="320")),
]


class Quiet(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *args):
        pass


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    root = os.path.abspath(sys.argv[1])
    only = set(sys.argv[2:])
    shots = [s for s in SHOTS if not only or s[0] in only]
    for scene in sorted({s[1] for s in shots}):
        subprocess.run(["luajit", "tools/render_ui.lua", os.path.join(root, scene + ".html"), scene],
                       check=True, capture_output=True)
    server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), functools.partial(Quiet, directory=root))
    threading.Thread(target=server.serve_forever, daemon=True).start()
    port = server.server_address[1]
    try:
        for name, scene, params in shots:
            query = dict(shot="1", scale="2.2")
            query.update(params)
            url = "http://127.0.0.1:%d/%s.html?%s" % (port, scene, urllib.parse.urlencode(query))
            out = os.path.abspath(os.path.join(OUT, name + ".png"))
            subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars",
                            "--force-device-scale-factor=1",
                            "--window-size=%s,%s" % (query.get("w", "1920"), query.get("h", "1080")),
                            "--virtual-time-budget=4000", "--screenshot=" + out, url],
                           check=True, capture_output=True)
            print("wrote", os.path.relpath(out))
    finally:
        server.shutdown()


if __name__ == "__main__":
    main()
