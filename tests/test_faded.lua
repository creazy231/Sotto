local T = T

-- A whisper into a faded window (Fade when idle: 4 s without the player at it)
-- counts unread until the player looks: the mouse over the window, the keyboard
-- in its box, a click on it. The light a whisper brings to the window is not the
-- player looking. With Keep windows open on by default the windows stay up, so
-- nothing that came in while the player was away may pass as read.

local function whisper(W, text, sender, o)
    W.chat("CHAT_MSG_WHISPER", W.whisperArgs(text, sender, o))
end

local function winOf(ns, key) return ns.Windows.For(ns.Store.Get(key)) end

-- The text of the first message under the log's New line.
local function underNewLine(log)
    for i, it in ipairs(log.items) do
        if it.kind == "new" then
            for j = i + 1, #log.items do
                if log.items[j].msg then return log.items[j].msg.m end
            end
        end
    end
end

-- Opened by a first whisper, then left alone until it fades.
local function faded(setup)
    local G, W, ns = T.load()
    if setup then setup(ns) end
    whisper(W, "hey", "Tarin Ashgrove")
    local c = ns.Store.Get("tarin ashgrove")
    W.advance(5)
    return G, W, ns, ns.UI, c
end

T.it("a whisper into the faded window counts unread until the mouse comes over it", function()
    local G, W, ns, UI, c = faded()
    T.eq(c.unread, 0, "the first one was read: the window opened on it")
    T.near(G.SottoWindow:GetAlpha(), 0.42, 0.01, "faded")
    whisper(W, "still there?", "Tarin Ashgrove")
    T.eq(c.unread, 1, "nobody was looking")
    W.advance(1)
    T.eq(G.SottoWindow:GetAlpha(), 1, "the whisper lights the window up")
    whisper(W, "hello?", "Tarin Ashgrove")
    T.eq(c.unread, 2, "that light is not the player looking")
    T.eq(ns.Rail.badges[1].count:GetText(), "2", "its badge says so")
    G.SottoWindow._mouseOver = true
    W.advance(0.25)
    T.eq(c.unread, 0, "the mouse over the window reads them")
end)

T.it("the New line goes above the first whisper nobody saw, and stays", function()
    local G, W, ns, UI, c = faded()
    whisper(W, "one", "Tarin Ashgrove")
    whisper(W, "two", "Tarin Ashgrove")
    T.eq(underNewLine(UI.log), "one")
    G.SottoWindow._mouseOver = true
    W.advance(0.25)
    T.eq(c.unread, 0)
    T.eq(underNewLine(UI.log), "one", "still there once read, as for a conversation opened unread")
end)

T.it("while the player is at the window, a whisper is read as before", function()
    local G, W, ns, UI, c = faded()
    G.SottoWindow._mouseOver = true
    W.advance(5)
    whisper(W, "a", "Tarin Ashgrove")
    T.eq(c.unread, 0, "the mouse over it")
    G.SottoWindow._mouseOver = false
    W.advance(2)
    whisper(W, "a2", "Tarin Ashgrove")
    T.eq(c.unread, 0, "a moment after the mouse left it")
    UI.compose.box:SetFocus()
    W.advance(10)
    whisper(W, "b", "Tarin Ashgrove")
    T.eq(c.unread, 0, "the keyboard in its box")
    UI.compose.box:ClearFocus()
    W.advance(2)
    whisper(W, "c", "Tarin Ashgrove")
    T.eq(c.unread, 0, "a moment after the player left it")
end)

T.it("scrolled back, the New line for an unseen whisper keeps the view where it was", function()
    local G, W, ns = T.load()
    for i = 1, 30 do whisper(W, "line " .. i, "Tarin Ashgrove") end
    local log = ns.UI.log
    W.advance(5)
    log:Scroll(2)
    T.ok(log.offset > 0, "scrolled back")
    local top = log.total - log.offset
    whisper(W, "still there?", "Tarin Ashgrove")
    T.eq(ns.Store.Get("tarin ashgrove").unread, 1)
    T.eq(underNewLine(log), "still there?")
    T.eq(log.total - log.offset, top, "what was in view stays in view")
end)

T.it("the mouse that has just come over the faded window counts at once", function()
    local G, W, ns, UI, c = faded()
    G.SottoWindow._mouseOver = true
    whisper(W, "a", "Tarin Ashgrove")
    T.eq(c.unread, 0)
end)

T.it("the player bringing the conversation up counts as being at the window", function()
    local G, W, ns, UI, c = faded()
    UI.Open(c)
    whisper(W, "a", "Tarin Ashgrove")
    T.eq(c.unread, 0, "a /w, the reply key or its badge just brought it up")
end)

T.it("with Fade when idle off, a whisper into the open window is read as before", function()
    local G, W, ns, UI, c = faded()
    ns.Set("fadeIdle", false)
    W.advance(30)
    whisper(W, "a", "Tarin Ashgrove")
    T.eq(c.unread, 0)
end)

T.it("the keyboard in its box or a click on its badge reads them", function()
    local G, W, ns, UI, c = faded()
    whisper(W, "a", "Tarin Ashgrove")
    T.eq(c.unread, 1)
    UI.compose.box:SetFocus()
    W.advance(0.25)
    T.eq(c.unread, 0, "the keyboard in its box")
    UI.compose.box:ClearFocus()
    W.advance(5)
    whisper(W, "b", "Tarin Ashgrove")
    T.eq(c.unread, 1)
    ns.Rail.badges[1]:Click("LeftButton")
    T.eq(c.unread, 0, "its badge")
end)

T.it("a faded window still gets the friend's online and offline lines, and they are not whispers", function()
    local G, W, ns, UI, c = faded()
    W.chat("CHAT_MSG_SYSTEM", G.ERR_FRIEND_OFFLINE_S:format("Tarin Ashgrove"))
    T.eq(c.msgs[#c.msgs].s, "offline", "on screen, if faded")
    T.eq(c.unread, 0)
end)

T.it("a faded window on no conversation takes up the whisper, unread", function()
    local G, W, ns = T.load()
    ns.UI.Show()
    T.eq(ns.UI.View(), "empty")
    W.advance(5)
    whisper(W, "hey", "Tarin Ashgrove")
    local c = ns.Store.Get("tarin ashgrove")
    T.eq(ns.UI.Active(), c, "it shows the whisper")
    T.eq(c.unread, 1, "nobody was looking")
    T.eq(underNewLine(ns.UI.log), "hey")
    G.SottoWindow._mouseOver = true
    W.advance(0.25)
    T.eq(c.unread, 0)
end)

T.it("with the player at it, the window on no conversation takes up the whisper read", function()
    local G, W, ns = T.load()
    ns.UI.Show()
    G.SottoWindow._mouseOver = true
    W.advance(5)
    whisper(W, "hey", "Tarin Ashgrove")
    T.eq(ns.Store.Get("tarin ashgrove").unread, 0)
end)

T.it("with separate windows, a faded window counts unread until the mouse comes over it", function()
    local G, W, ns, UI, c = faded(function(ns) ns.Set("separate", true) end)
    local w = winOf(ns, "tarin ashgrove")
    T.near(w.frame:GetAlpha(), 0.42, 0.01, "faded")
    whisper(W, "still there?", "Tarin Ashgrove")
    T.eq(c.unread, 1, "unread")
    T.eq(underNewLine(w.pane.log), "still there?", "the New line above it")
    whisper(W, "hello?", "Tarin Ashgrove")
    T.eq(c.unread, 2, "the light it brings is not a look")
    G.SottoWindow._mouseOver = true
    W.advance(0.25)
    T.eq(c.unread, 2, "the mouse over the dock is not over the window")
    G.SottoWindow._mouseOver = false
    w.frame._mouseOver = true
    W.advance(0.25)
    T.eq(c.unread, 0, "the mouse over the window reads it")
end)

T.it("a whisper that brings up a covered window while nobody is there leaves it unread", function()
    local G, W, ns = T.load()
    ns.Set("separate", true)
    whisper(W, "a", "Aaa")
    whisper(W, "b", "Bbb")
    W.advance(5)
    whisper(W, "still there?", "Aaa")
    local a, b = winOf(ns, "aaa"), winOf(ns, "bbb")
    T.ok(a.frame._raisedAt > b.frame._raisedAt, "it still comes to the front")
    T.eq(ns.Store.Get("aaa").unread, 1, "but nobody saw it")
    whisper(W, "hello?", "Aaa")
    T.eq(ns.Store.Get("aaa").unread, 2, "coming up for a whisper is not a look")
    a.frame._mouseOver = true
    W.advance(0.25)
    T.eq(ns.Store.Get("aaa").unread, 0)
end)

T.it("with separate windows, a click on its badge in the dock reads a faded window", function()
    local G, W, ns, UI, c = faded(function(ns) ns.Set("separate", true) end)
    whisper(W, "still there?", "Tarin Ashgrove")
    T.eq(c.unread, 1)
    ns.Rail.badges[1]:Click("LeftButton")
    T.eq(c.unread, 0)
end)

T.it("a menu open in another window does not read a faded one", function()
    local G, W, ns = T.load()
    ns.Set("separate", true)
    whisper(W, "a", "Aaa")
    whisper(W, "b", "Bbb")
    W.advance(5)
    whisper(W, "still there?", "Bbb")
    T.eq(ns.Store.Get("bbb").unread, 1)
    local a = winOf(ns, "aaa")
    a.pane:MoreMenu(a.pane.head.more)
    W.advance(0.25)
    T.eq(ns.Store.Get("bbb").unread, 1, "Aaa's menu is not a look at Bbb")
end)

T.it("the mouse over a covered window does not read it", function()
    local G, W, ns = T.load()
    ns.Set("separate", true)
    whisper(W, "a", "Aaa")
    whisper(W, "b", "Bbb")
    W.combat = true
    whisper(W, "lf healer?", "Aaa")
    T.eq(ns.Store.Get("aaa").unread, 1)
    winOf(ns, "aaa").frame._mouseOver = true
    W.advance(0.25)
    T.eq(ns.Store.Get("aaa").unread, 1, "Bbb lies over it")
end)

T.it("a faded window that comes into view stays unread until the mouse comes over it", function()
    local G, W, ns = T.load()
    ns.Set("separate", true)
    whisper(W, "a", "Aaa")
    whisper(W, "b", "Bbb")
    W.combat = true
    whisper(W, "lf healer?", "Aaa")
    T.eq(ns.Store.Get("aaa").unread, 1, "covered, in combat: a card")
    W.advance(5)
    winOf(ns, "bbb").pane.head.close:Click()
    T.eq(ns.Store.Get("aaa").unread, 1, "Bbb minimised, but nobody looked at Aaa's faded window yet")
    winOf(ns, "aaa").frame._mouseOver = true
    W.advance(0.25)
    T.eq(ns.Store.Get("aaa").unread, 0)
end)

T.it("a menu open in another window does not count as being at a faded one", function()
    local G, W, ns = T.load()
    ns.Set("separate", true)
    whisper(W, "a", "Aaa")
    whisper(W, "b", "Bbb")
    W.advance(5)
    local a = winOf(ns, "aaa")
    a.pane:MoreMenu(a.pane.head.more)
    ns.W.CurrentMenu()._mouseOver = true
    W.advance(1)
    whisper(W, "still there?", "Bbb")
    T.eq(ns.Store.Get("bbb").unread, 1, "the mouse in Aaa's menu is no look at Bbb")
    T.near(winOf(ns, "bbb").frame:GetAlpha(), 0.42, 0.01, "nor does Aaa's menu keep Bbb lit")
end)

T.it("a menu left open while nobody is there does not keep whispers read", function()
    local G, W, ns, UI, c = faded()
    UI.MoreMenu(UI.header.more)
    W.advance(10)
    T.eq(G.SottoWindow:GetAlpha(), 1, "its open menu keeps it lit")
    whisper(W, "still there?", "Tarin Ashgrove")
    T.eq(c.unread, 1)
end)

T.it("a separate window asking for a name stays lit while the name is typed", function()
    local G, W, ns = T.load()
    ns.Set("separate", true)
    ns.UI.NewConversation()
    local w
    for _, o in ipairs(ns.Windows.all) do if o.used and not o.conv then w = o end end
    T.ok(w and w.pane.prompt.edit:HasFocus(), "the Whisper to field has the keyboard")
    W.advance(10)
    T.eq(w.frame:GetAlpha(), 1)
end)

T.it("the mouse over the window's own menu counts as being at it", function()
    local G, W, ns, UI, c = faded()
    UI.MoreMenu(UI.header.more)
    ns.W.CurrentMenu()._mouseOver = true
    W.advance(10)
    whisper(W, "a", "Tarin Ashgrove")
    T.eq(c.unread, 0)
end)

T.it("the mouse over something lying on top of the window does not count", function()
    local G, W, ns, UI, c = faded()
    whisper(W, "still there?", "Tarin Ashgrove")
    T.eq(c.unread, 1)
    local map = G.CreateFrame("Frame", "TestMapFrame", G.UIParent)
    G.GetMouseFoci = function() return { map } end
    G.SottoWindow._mouseOver = true
    W.advance(0.25)
    T.eq(c.unread, 1, "the map lies over it there")
    map.IsForbidden = function() return true end
    map.GetParent = function() error("attempt to access a forbidden object") end
    W.advance(0.25)
    T.eq(c.unread, 1, "nor a frame the game keeps from addons, which is not touched")
    G.GetMouseFoci = function() return { UI.compose.box } end
    W.advance(0.25)
    T.eq(c.unread, 0, "over one of its own frames: read")
end)

T.it("typing a name in the window's Whisper to field counts as being at it", function()
    local G, W, ns, UI, c = faded()
    UI.NewConversation()
    W.advance(10)
    whisper(W, "a", "Tarin Ashgrove")
    T.eq(c.unread, 0)
end)

T.it("after Clear history no New line comes back at the old place", function()
    local G, W, ns, UI, c = faded()
    whisper(W, "one", "Tarin Ashgrove")
    G.SottoWindow._mouseOver = true
    W.advance(0.25)
    ns.Store.Clear(c)
    for _, t in ipairs({ "a", "b", "c" }) do whisper(W, t, "Tarin Ashgrove") end
    T.eq(underNewLine(UI.log), nil)
end)

T.it("in a full conversation the New line stays on its message", function()
    local G, W, ns, UI, c = faded()
    for i = 1, 400 do ns.Store.Add(c, "i", "old " .. i, G.time()) end
    whisper(W, "unseen", "Tarin Ashgrove")
    G.SottoWindow._mouseOver = true
    W.advance(0.25)
    for i = 1, 3 do whisper(W, "after" .. i, "Tarin Ashgrove") end
    T.eq(#c.msgs, 400, "full: the oldest go")
    T.eq(underNewLine(UI.log), "unseen")
end)

T.it("while the interface is hidden (Alt+Z), a whisper counts unread", function()
    local G, W, ns = T.load()
    whisper(W, "hey", "Tarin Ashgrove")
    local c = ns.Store.Get("tarin ashgrove")
    G.UIParent:Hide()
    whisper(W, "still there?", "Tarin Ashgrove")
    T.eq(c.unread, 1, "nobody can see it")
    G.UIParent:Show()
end)
