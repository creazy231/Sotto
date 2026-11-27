local T = T

-- Keep windows open (Settings, Look; on by default): Sotto's windows are not among
-- the game's special frames, which Esc, every loading screen, death, losing control
-- and Alt+Z hide; what is on screen at logout comes back at the next login, and
-- after the gamepad interface.

local function load(opts)
    local G, W, ns = T.load(opts)
    return G, W, ns, ns.UI
end

local function separate(opts)
    local G, W, ns, UI = load(opts)
    ns.Set("separate", true)
    return G, W, ns, UI
end

local function whisper(W, text, sender, o)
    W.chat("CHAT_MSG_WHISPER", W.whisperArgs(text, sender, o))
end

local function winOf(ns, key) return ns.Windows.For(ns.Store.Get(key)) end

local function shown(ns, key)
    local w = winOf(ns, key)
    return w ~= nil and w.frame:IsShown()
end

-- Blizzard's CloseSpecialWindows (Esc, loading screens, death, losing control, Alt+Z):
-- every shown frame named in UISpecialFrames hides.
local function closeAll(G)
    for _, name in ipairs(G.UISpecialFrames) do
        local f = G[name]
        if f and f:IsShown() then f:Hide() end
    end
end

local function listed(G, name)
    local n = 0
    for _, v in ipairs(G.UISpecialFrames) do if v == name then n = n + 1 end end
    return n
end

local function corner(f)
    local p, _, rp, x, y = f:GetPoint(1)
    assert(p == "BOTTOMLEFT" and rp == "BOTTOMLEFT", "anchored by its bottom-left corner")
    return x, y
end

local function reload(G, opts)
    opts = opts or {}
    opts.db = G.SottoDB
    return load(opts)
end

T.it("Keep windows open is on by default and sits right under Separate windows", function()
    local G, W, ns, UI = load()
    T.eq(ns.Get("keepOpen"), true, "on by default")
    UI.ShowSettings()
    local C = ns.Settings.controls
    T.ok(C.keepOpen, "a Keep windows open control")
    local row = C.keepOpen:GetParent()
    T.eq(row.label:GetText(), "Keep windows open")
    T.eq(row.desc:GetText(), "Esc and loading screens leave them open, and they come back after a reload")
    T.ok(C.separate:GetParent():GetTop() > row:GetTop() and row:GetTop() > C.accent:GetParent():GetTop(),
        "between Separate windows and Accent")
    C.keepOpen:Click()
    T.eq(ns.Get("keepOpen"), false, "the switch turns it off")
    T.eq(select(4, C.keepOpen.knob:GetPoint(1)), 2, "and shows it off")
    C.keepOpen:Click()
    T.eq(ns.Get("keepOpen"), true, "and on again")
end)

T.it("what closes the game's windows leaves Sotto's window open", function()
    local G, W, ns, UI = load()
    whisper(W, "hey", "Tarin Ashgrove")
    T.ok(G.SottoWindow:IsShown())
    T.eq(listed(G, "SottoWindow"), 0, "not one of the game's special frames")
    ns.CopyBox.Show("Link", "https://example.org")
    UI.MoreMenu(UI.header.more)
    T.ok(G.SottoCopyBox:IsShown() and G.SottoMenu:IsShown())
    closeAll(G)
    T.ok(G.SottoWindow:IsShown(), "still open")
    T.no(G.SottoCopyBox:IsShown(), "the copy box still closes with Esc")
    T.no(G.SottoMenu:IsShown(), "and so does a menu")
end)

T.it("with Keep windows open off, Esc closes the window as before", function()
    local G, W, ns, UI = load()
    ns.Set("keepOpen", false)
    T.eq(listed(G, "SottoWindow"), 1, "a special frame again")
    whisper(W, "hey", "Tarin Ashgrove")
    closeAll(G)
    T.no(G.SottoWindow:IsShown(), "Esc closes it")
    ns.Set("keepOpen", true)
    T.eq(listed(G, "SottoWindow"), 0, "on again: off the list")
    ns.Set("keepOpen", false)
    T.eq(listed(G, "SottoWindow"), 1, "listed once, however often it is switched")
end)

T.it("saved off, the window is a special frame from the start", function()
    local G = load({ db = { settings = { keepOpen = false } } })
    T.eq(listed(G, "SottoWindow"), 1)
end)

T.it("separate windows and the dock stay open too, and follow the setting", function()
    local G, W, ns, UI = separate()
    whisper(W, "a", "Aaa")
    UI.Toggle() -- the dock
    local a = winOf(ns, "aaa").frame:GetName()
    T.eq(listed(G, a), 0, "a window made while it is on is not listed")
    closeAll(G)
    T.ok(shown(ns, "aaa"), "the window stays")
    T.ok(G.SottoWindow:IsShown(), "the dock stays")
    ns.Set("keepOpen", false)
    T.eq(listed(G, a), 1, "off: listed")
    T.eq(listed(G, "SottoWindow"), 1)
    whisper(W, "b", "Bbb")
    T.eq(listed(G, winOf(ns, "bbb").frame:GetName()), 1, "a window made while it is off is listed")
    closeAll(G)
    T.no(ns.Windows.AnyShown(), "Esc minimises them")
    T.no(G.SottoWindow:IsShown(), "and hides the dock")
end)

T.it("the window comes back after a reload, on the conversation it showed", function()
    local G, W, ns, UI = load()
    whisper(W, "a", "Aaa")
    W.clock = W.clock + 60
    whisper(W, "b", "Bbb")
    T.eq(ns.Store.List()[1], ns.Store.Get("bbb"), "Bbb is the newest")
    T.eq(UI.Active(), ns.Store.Get("aaa"), "Bbb's whisper left the window on Aaa")
    W.fire("PLAYER_LOGOUT")
    local G2, W2, ns2, UI2 = reload(G)
    T.ok(G2.SottoWindow:IsShown(), "open again")
    T.eq(UI2.Active(), ns2.Store.Get("aaa"), "on Aaa, not on the newest")
    T.eq(ns2.Store.Get("bbb").unread, 1, "Bbb is still unread")
end)

T.it("a window closed by hand stays closed after a reload", function()
    local G, W, ns, UI = load()
    whisper(W, "a", "Aaa")
    UI.header.close:Click()
    T.no(G.SottoWindow:IsShown())
    W.fire("PLAYER_LOGOUT")
    local G2 = reload(G)
    T.no(G2.SottoWindow:IsShown())
end)

T.it("with Keep windows open off, a reload brings nothing back", function()
    local G, W, ns, UI = load()
    ns.Set("keepOpen", false)
    whisper(W, "a", "Aaa")
    W.fire("PLAYER_LOGOUT")
    local G2 = reload(G)
    T.no(G2.SottoWindow:IsShown())
end)

T.it("only the login brings it back: a later loading screen leaves a closed window closed", function()
    local G, W, ns, UI = load()
    whisper(W, "a", "Aaa")
    W.fire("PLAYER_LOGOUT")
    local G2, W2, ns2, UI2 = reload(G)
    T.ok(G2.SottoWindow:IsShown())
    UI2.Hide()
    W2.fire("PLAYER_ENTERING_WORLD", false, false)
    W2.advance(0)
    T.no(G2.SottoWindow:IsShown())
end)

T.it("with history kept until logout, the window comes back empty", function()
    local G, W, ns, UI = load()
    ns.Set("keepDays", 0)
    whisper(W, "a", "Aaa")
    W.fire("PLAYER_LOGOUT")
    local G2, W2, ns2, UI2 = reload(G)
    T.ok(G2.SottoWindow:IsShown(), "open again")
    T.eq(UI2.View(), "empty", "the login cleared the history")
    T.eq(#ns2.Store.List(), 0)
end)

T.it("separate windows and the dock come back after a reload, in their places, the front one in front", function()
    local G, W, ns, UI = separate()
    whisper(W, "a", "Aaa")
    whisper(W, "b", "Bbb")
    whisper(W, "c", "Ccc")
    winOf(ns, "bbb").pane.head.close:Click() -- minimised
    UI.Open(ns.Store.Get("aaa"))              -- in front
    UI.Toggle()                               -- the dock
    local ax, ay = corner(winOf(ns, "aaa").frame)
    local cx, cy = corner(winOf(ns, "ccc").frame)
    W.fire("PLAYER_LOGOUT")
    local G2, W2, ns2, UI2 = reload(G)
    T.ok(G2.SottoWindow:IsShown(), "the dock")
    T.eq(UI2.View(), "dock")
    T.ok(shown(ns2, "aaa"), "Aaa's window")
    T.ok(shown(ns2, "ccc"), "Ccc's window")
    T.eq(winOf(ns2, "bbb"), nil, "Bbb stays minimised")
    T.eq(ns2.Windows.Front(), ns2.Store.Get("aaa"), "Aaa in front")
    local ax2, ay2 = corner(winOf(ns2, "aaa").frame)
    local cx2, cy2 = corner(winOf(ns2, "ccc").frame)
    T.eq(ax2, ax); T.eq(ay2, ay, "Aaa where it was")
    T.eq(cx2, cx); T.eq(cy2, cy, "Ccc where it was")
    T.eq(ns2.Store.Get("aaa").win, nil, "a place the player did not choose stays unsaved")
end)

T.it("a dock hidden by hand stays hidden after a reload; the windows come back", function()
    local G, W, ns, UI = separate()
    whisper(W, "a", "Aaa")
    UI.Toggle()
    UI.Toggle()
    T.no(G.SottoWindow:IsShown())
    W.fire("PLAYER_LOGOUT")
    local G2, W2, ns2 = reload(G)
    T.no(G2.SottoWindow:IsShown(), "no dock")
    T.ok(shown(ns2, "aaa"), "Aaa's window")
end)

T.it("a window minimised before the logout stays minimised", function()
    local G, W, ns, UI = separate()
    whisper(W, "a", "Aaa")
    winOf(ns, "aaa").pane.head.close:Click()
    W.fire("PLAYER_LOGOUT")
    local G2, W2, ns2 = reload(G)
    T.eq(winOf(ns2, "aaa"), nil)
    T.no(ns2.Windows.AnyShown())
end)

T.it("a window minimised after one reload stays minimised after the next", function()
    local G, W, ns, UI = separate()
    whisper(W, "a", "Aaa")
    W.fire("PLAYER_LOGOUT")
    local G2, W2, ns2 = reload(G)
    T.ok(shown(ns2, "aaa"))
    winOf(ns2, "aaa").pane.head.close:Click()
    W2.fire("PLAYER_LOGOUT")
    local G3, W3, ns3 = reload(G2)
    T.no(ns3.Windows.AnyShown())
end)

T.it("after the gamepad interface, the window comes back", function()
    local G, W, ns, UI = load()
    whisper(W, "a", "Aaa")
    W.switchStyle("Gamepad")
    W.advance(0)
    T.no(UI.IsShown(), "the gamepad interface closes it")
    W.switchStyle("Mkb")
    W.advance(0)
    T.ok(G.SottoWindow:IsShown(), "back with mouse and keyboard")
    T.eq(UI.Active(), ns.Store.Get("aaa"))
end)

T.it("after the gamepad interface, a conversation closed meanwhile stays closed", function()
    local G, W, ns, UI = load()
    whisper(W, "a", "Aaa")
    whisper(W, "b", "Bbb")
    W.switchStyle("Gamepad")
    W.advance(0)
    ns.Store.Close(ns.Store.Get("aaa"))
    W.switchStyle("Mkb")
    W.advance(0)
    T.ok(G.SottoWindow:IsShown(), "the window comes back")
    T.no(ns.Store.Get("aaa").open, "Aaa stays closed")
    T.eq(UI.Active(), ns.Store.Get("bbb"), "on the conversation left")
end)

T.it("after the gamepad interface, the separate windows and the dock come back", function()
    local G, W, ns, UI = separate()
    whisper(W, "a", "Aaa")
    whisper(W, "b", "Bbb")
    whisper(W, "c", "Ccc")
    winOf(ns, "bbb").pane.head.close:Click()
    UI.Toggle()
    W.switchStyle("Gamepad")
    W.advance(0)
    T.no(UI.IsShown())
    ns.Store.Close(ns.Store.Get("ccc")) -- closed meanwhile
    whisper(W, "lf healer?", "Ddd")    -- arrives in the game's chat
    W.switchStyle("Mkb")
    W.advance(0)
    T.ok(G.SottoWindow:IsShown(), "the dock")
    T.ok(shown(ns, "aaa"), "Aaa's window")
    T.eq(winOf(ns, "bbb"), nil, "the minimised one stays minimised")
    T.no(ns.Store.Get("ccc").open, "a conversation closed meanwhile stays closed")
    T.eq(winOf(ns, "ccc"), nil)
    T.eq(winOf(ns, "ddd"), nil, "nothing opens that was not open")
end)

T.it("a logout in the gamepad interface keeps for the next login what was open before it", function()
    local G, W, ns, UI = load()
    whisper(W, "a", "Aaa")
    W.switchStyle("Gamepad")
    W.advance(0)
    W.fire("PLAYER_LOGOUT")
    local G2 = reload(G)
    T.ok(G2.SottoWindow:IsShown())
end)

T.it("a login in the gamepad interface opens nothing until mouse and keyboard are back", function()
    local G, W, ns, UI = load()
    whisper(W, "a", "Aaa")
    W.fire("PLAYER_LOGOUT")
    local G2, W2, ns2, UI2 = reload(G, { gamepad = true })
    T.no(G2.SottoWindow:IsShown(), "the controller cannot reach it")
    W2.fire("PLAYER_LOGOUT")
    local G3, W3, ns3, UI3 = reload(G2, { gamepad = true })
    T.no(G3.SottoWindow:IsShown())
    W3.switchStyle("Mkb")
    W3.advance(0)
    T.ok(G3.SottoWindow:IsShown(), "it comes when the gamepad interface goes")
    T.eq(UI3.Active(), ns3.Store.Get("aaa"))
end)

-- After the fresh-eyes review.

T.it("a covered window that was unread before the reload is still unread after it", function()
    local G, W, ns, UI = separate()
    whisper(W, "a", "Aaa")
    whisper(W, "b", "Bbb")      -- Bbb's window opens over Aaa's
    W.combat = true
    whisper(W, "still there?", "Aaa")
    W.combat = false
    local a = ns.Store.Get("aaa")
    T.eq(a.unread, 1, "unread: covered, in combat")
    W.fire("PLAYER_LOGOUT")
    local G2, W2, ns2 = reload(G)
    local a2 = ns2.Store.Get("aaa")
    T.ok(shown(ns2, "aaa"), "Aaa's window is back")
    T.no(ns2.UI.Sees(a2), "still covered by Bbb's")
    T.eq(a2.unread, 1, "and still unread")
end)

T.it("a window comes back clear of one opened at its place meanwhile", function()
    local G, W, ns, UI = separate()
    whisper(W, "a", "Aaa")
    W.switchStyle("Gamepad")
    W.advance(0)
    UI.Open(ns.Store.Ensure("w", "Bbb")) -- by hand, at the first step
    W.switchStyle("Mkb")
    W.advance(0)
    local ax, ay = corner(winOf(ns, "aaa").frame)
    local bx, by = corner(winOf(ns, "bbb").frame)
    T.ok(ax ~= bx or ay ~= by, "not exactly on top of each other")
end)

T.it("turning separate windows on during the gamepad interface: the conversation comes back in its own window", function()
    local G, W, ns, UI = load()
    whisper(W, "a", "Aaa")
    W.switchStyle("Gamepad")
    W.advance(0)
    ns.Set("separate", true)
    W.switchStyle("Mkb")
    W.advance(0)
    T.ok(shown(ns, "aaa"), "Aaa's window")
end)

T.it("turning separate windows off during the gamepad interface: the window comes back on the front one", function()
    local G, W, ns, UI = separate()
    whisper(W, "a", "Aaa")
    whisper(W, "b", "Bbb")
    UI.Open(ns.Store.Get("aaa")) -- in front; the dock stays hidden
    W.switchStyle("Gamepad")
    W.advance(0)
    ns.Set("separate", false)
    W.switchStyle("Mkb")
    W.advance(0)
    T.ok(G.SottoWindow:IsShown(), "the window")
    T.eq(UI.Active(), ns.Store.Get("aaa"), "on the one in front")
end)

T.it("a gamepad interface the client reports late keeps what the login was to bring back", function()
    local G, W, ns, UI = load()
    whisper(W, "a", "Aaa")
    W.fire("PLAYER_LOGOUT")
    local G2, W2, ns2, UI2 = reload(G, { login = false })
    W2.fire("PLAYER_LOGIN")                -- the style still reads mouse and keyboard
    W2.interfaceStyle = 1                  -- known by the first loading screen
    W2.fire("PLAYER_ENTERING_WORLD", true, false)
    W2.advance(0)
    T.no(G2.SottoWindow:IsShown(), "kept for later")
    W2.fire("INPUT_DEVICE_INTERFACE_TRANSITION", 1, 0)
    W2.advance(0)
    W2.switchStyle("Mkb")
    W2.advance(0)
    T.ok(G2.SottoWindow:IsShown(), "back with mouse and keyboard")
end)

T.it("hiding the interface (Alt+Z) leaves separate windows open", function()
    local G, W, ns = separate()
    whisper(W, "hey", "Tarin Ashgrove")
    local w = winOf(ns, "tarin ashgrove")
    local f = w.frame
    -- WoW hides UIParent: its children get OnHide while their own shown flag stays on.
    f:GetScript("OnHide")(f)
    T.eq(winOf(ns, "tarin ashgrove"), w, "still its window, not minimised")
    T.ok(f:IsShown())
    f:GetScript("OnShow")(f)
    T.ok(shown(ns, "tarin ashgrove"), "there when the interface comes back")
end)
