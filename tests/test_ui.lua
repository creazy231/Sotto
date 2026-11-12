local T = T

local function load(opts)
    local G, W, ns = T.load(opts)
    return G, W, ns, ns.UI
end

local function whisper(W, text, sender, o)
    W.chat("CHAT_MSG_WHISPER", W.whisperArgs(text, sender, o))
end

local function itemsOf(ns, kind)
    local n = 0
    for _, it in ipairs(ns.Log.items) do if it.kind == kind then n = n + 1 end end
    return n
end

T.it("window builds hidden with the saved size", function()
    local G, W, ns, UI = load()
    T.ok(G.SottoWindow, "named frame")
    T.no(G.SottoWindow:IsShown(), "hidden")
    T.eq(G.SottoWindow:GetWidth(), 410)
    T.eq(G.SottoWindow:GetHeight(), 306)
    T.has(G.UISpecialFrames, "SottoWindow", "Esc closes it")
end)

T.it("a whisper out of combat opens the window on that conversation", function()
    local G, W, ns, UI = load()
    whisper(W, "hey", "Tarin Ashgrove", { guid = "Player-2-0001" })
    T.ok(UI.IsShown(), "shown")
    local c = ns.Store.Get("tarin ashgrove")
    T.eq(UI.Active(), c)
    T.eq(c.unread, 0)
    T.eq(UI.header.name:GetText(), "Tarin Ashgrove")
    T.no(W.focus, "no keyboard focus taken")
end)

T.it("a whisper in combat shows a toast; clicking it opens and focuses", function()
    local G, W, ns, UI = load()
    W.combat = true
    whisper(W, "lf healer?", "Kaja Stormhoof")
    T.no(UI.IsShown(), "window stays closed")
    T.eq(#ns.Toast.active, 1)
    local toast = ns.Toast.active[1]
    T.eq(toast.name:GetText(), "Kaja Stormhoof")
    whisper(W, "anyone?", "Kaja Stormhoof")
    T.eq(#ns.Toast.active, 1, "one card per conversation")
    T.eq(toast.count:GetText(), "+1")
    W.combat = false
    toast:Click("LeftButton")
    T.ok(UI.IsShown())
    T.eq(UI.Active(), ns.Store.Get("kaja stormhoof"))
    T.eq(W.focus, ns.Compose.box, "compose focused")
    T.eq(#ns.Toast.active, 0, "toast gone")
end)

T.it("a toast hides itself after a while and right-click dismisses", function()
    local G, W, ns, UI = load()
    ns.Set("openOn", "never")
    whisper(W, "a", "Aaa")
    T.eq(#ns.Toast.active, 1)
    W.advance(9)
    T.eq(#ns.Toast.active, 0, "timed out")
    whisper(W, "b", "Bbb")
    ns.Toast.active[1]:Click("RightButton")
    T.eq(#ns.Toast.active, 0, "dismissed")
    T.no(UI.IsShown())
end)

T.it("rail shows one badge per open conversation with unread pills", function()
    local G, W, ns, UI = load()
    whisper(W, "a", "Aaa")
    whisper(W, "b", "Bbb")
    T.eq(#ns.Rail.badges, 2)
    T.eq(ns.Rail.badges[1].conv.key, "bbb", "newest first")
    T.ok(ns.Rail.badges[1].pill:IsShown(), "unread pill")
    T.eq(ns.Rail.badges[1].count:GetText(), "1")
    T.no(ns.Rail.badges[2].pill:IsShown(), "active one read")
    T.ok(ns.Rail.badges[2].active, "active marker")
    ns.Rail.badges[1]:Click("LeftButton")
    T.eq(UI.Active().key, "bbb")
    T.eq(ns.Store.Get("bbb").unread, 0)
end)

T.it("log groups runs within 5 minutes and adds day separators", function()
    local G, W, ns, UI = load()
    local c = ns.Store.Ensure("w", "Aaa")
    local t0 = G.time() - 3600
    ns.Store.Add(c, "i", "one", t0)
    ns.Store.Add(c, "i", "two", t0 + 60)
    ns.Store.Add(c, "o", "three", t0 + 120)
    ns.Store.Add(c, "i", "four", t0 + 600)
    UI.Open(c)
    T.eq(itemsOf(ns, "day"), 1)
    T.eq(itemsOf(ns, "head"), 3)
    T.eq(itemsOf(ns, "line"), 4)
    T.ok(#ns.Log.rows > 0, "rows drawn")
end)

T.it("the New divider marks the first unread message", function()
    local G, W, ns, UI = load()
    local c = ns.Store.Ensure("w", "Aaa")
    local t0 = G.time() - 600
    ns.Store.Add(c, "i", "old1", t0)
    ns.Store.Add(c, "i", "old2", t0 + 10)
    ns.Store.Add(c, "i", "new1", t0 + 400)
    ns.Store.Add(c, "i", "new2", t0 + 410)
    ns.Store.MarkUnread(c, 2)
    UI.Open(c)
    local before
    for i, it in ipairs(ns.Log.items) do
        if it.kind == "new" then before = ns.Log.items[i + 1] or ns.Log.items[i + 2] end
    end
    T.ok(before, "divider present")
    local nextLine
    for i, it in ipairs(ns.Log.items) do
        if it.kind == "new" then
            for j = i + 1, #ns.Log.items do
                if ns.Log.items[j].kind == "line" then nextLine = ns.Log.items[j]; break end
            end
        end
    end
    T.eq(nextLine.msg.m, "new1")
end)

T.it("divider lines are one pixel high", function()
    local G, W, ns, UI = load()
    local c = ns.Store.Ensure("w", "Aaa")
    local t0 = G.time() - 600
    ns.Store.Add(c, "i", "old", t0)
    ns.Store.Add(c, "i", "new", t0 + 400)
    ns.Store.MarkUnread(c, 1)
    UI.Open(c)
    local seen = {}
    for _, r in ipairs(ns.Log.rows) do
        if r.kind == "new" then
            seen.new = true
            T.near(r.line:GetHeight(), 768 / 1080, 1e-6, "New line height")
        elseif r.kind == "day" then
            seen.day = true
            T.near(r.left:GetHeight(), 768 / 1080, 1e-6, "day line height")
        end
    end
    T.ok(seen.new and seen.day, "both drawn")
end)

T.it("Enter in the compose box sends, keeps focus, and Up recalls", function()
    local G, W, ns, UI = load()
    W.resting = true
    UI.Open(ns.Store.Ensure("w", "Tarin Ashgrove"), { focus = true })
    local box = ns.Compose.box
    box:SetText("hello there")
    box:_fire("OnEnterPressed")
    T.eq(#W.sent, 1)
    T.eq(W.sent[1].msg, "hello there")
    T.eq(W.sent[1].target, "Tarin Ashgrove")
    T.eq(box:GetText(), "")
    T.eq(W.focus, box, "focus kept")
    box:_fire("OnArrowPressed", "UP")
    T.eq(box:GetText(), "hello there")
    box:_fire("OnArrowPressed", "DOWN")
    T.eq(box:GetText(), "")
end)

T.it("Enter on an empty box and Esc leave it", function()
    local G, W, ns, UI = load()
    UI.Open(ns.Store.Ensure("w", "Tarin Ashgrove"), { focus = true })
    local box = ns.Compose.box
    box:_fire("OnEnterPressed")
    T.no(W.focus, "left on empty Enter")
    box:SetFocus()
    box:_fire("OnEscapePressed")
    T.no(W.focus, "left on Esc")
end)

T.it("opening with text carries the draft over", function()
    local G, W, ns, UI = load()
    UI.Open(ns.Store.Ensure("w", "Tarin Ashgrove"), { focus = true, text = "typed in chat" })
    T.eq(ns.Compose.box:GetText(), "typed in chat")
end)

T.it("drafts stay with their conversation", function()
    local G, W, ns, UI = load()
    local a, b = ns.Store.Ensure("w", "Aaa"), ns.Store.Ensure("w", "Bbb")
    UI.Open(a)
    ns.Compose.box:SetText("for a")
    UI.Open(b)
    T.eq(ns.Compose.box:GetText(), "")
    UI.Open(a)
    T.eq(ns.Compose.box:GetText(), "for a")
end)

T.it("lockdown shows the banner and pauses sending", function()
    local G, W, ns, UI = load()
    UI.Open(ns.Store.Ensure("w", "Tarin Ashgrove"), { focus = true })
    W.lockdown = true
    W.fire("ENCOUNTER_START")
    T.ok(UI.banner:IsShown(), "banner")
    T.ok(ns.Compose.placeholder:GetText():find("Paused", 1, true), "paused placeholder")
    ns.Compose.box:SetText("later")
    ns.Compose.box:_fire("OnEnterPressed")
    T.eq(#W.sent, 0)
    T.eq(ns.Compose.box:GetText(), "later", "draft kept")
    W.lockdown = false
    W.fire("ENCOUNTER_END")
    T.no(UI.banner:IsShown(), "banner gone")
end)

T.it("settings rows change settings", function()
    local G, W, ns, UI = load()
    UI.ShowSettings()
    T.eq(UI.View(), "settings")
    local C = ns.Settings.controls
    C.hideInChat:Click()
    T.eq(ns.Get("hideInChat"), false)
    C.openOn.buttons[1]:Click()
    T.eq(ns.Get("openOn"), "always")
    C.accent.buttons[2]:Click()
    T.eq(ns.Get("accent"), "eui")
    C.fontSize:SetTo(15)
    T.eq(ns.Get("fontSize"), 15)
    C.keepDays:Click()
    ns.W.CurrentMenu().rows[2]:Click()
    T.eq(ns.Get("keepDays"), 7)
    C.minimap:Click()
    T.eq(ns.Get("minimap"), false)
    T.no(G.SottoMinimapButton:IsShown(), "minimap button hidden")
end)

T.it("the whisper mode hint appears only when Blizzard opens whisper tabs", function()
    local G, W, ns, UI = load({ setup = function(G, W) W.cvars.whisperMode = "popout" end })
    UI.ShowSettings()
    T.ok(ns.Settings.whisperMode and ns.Settings.whisperMode:IsShown(), "hint shown")
    ns.Settings.whisperMode.action:Click()
    T.eq(W.cvars.whisperMode, "inline")
end)

T.it("minimap button shows the unread total", function()
    local G, W, ns, UI = load()
    ns.Set("openOn", "never")
    whisper(W, "a", "Aaa")
    whisper(W, "b", "Aaa")
    local b = G.SottoMinimapButton
    T.ok(b, "button")
    T.ok(b.pill:IsShown())
    T.eq(b.count:GetText(), "2")
    b:Click("LeftButton")
    T.ok(UI.IsShown(), "click opens")
end)

T.it("WIM notice turns WIM off and offers a reload", function()
    local G, W, ns, UI = load({ setup = function(G, W) W.loadedAddons.WIM = true; W.loadedAddons.EllesmereSkin_WIM = true end })
    UI.Open(ns.Store.Ensure("w", "Aaa"))
    T.ok(UI.notice:IsShown(), "notice")
    UI.notice.action:Click()
    T.ok(W.disabledAddons.WIM, "WIM disabled")
    T.ok(W.disabledAddons.EllesmereSkin_WIM, "its skin too")
    UI.notice.action:Click()
    T.eq(W.reloads, 1)
end)

T.it("clicking a URL opens the copy box", function()
    local G, W, ns, UI = load()
    whisper(W, "see https://polestar.guide/community", "Aaa")
    local row
    for _, r in ipairs(ns.Log.rows) do if r.kind == "line" then row = r end end
    T.ok(row, "line row")
    row:_fire("OnHyperlinkClick", "sotto:url:https://polestar.guide/community", "x", "LeftButton")
    T.ok(G.SottoCopyBox:IsShown(), "copy box")
    T.eq(G.SottoCopyBox.edit:GetText(), "https://polestar.guide/community")
end)

T.it("other links go to SetItemRef with the row as the frame", function()
    local G, W, ns, UI = load()
    whisper(W, "|cffffffff|Hitem:2581|h[Heavy Linen Bandage]|h|r", "Aaa")
    local row
    for _, r in ipairs(ns.Log.rows) do if r.kind == "line" then row = r end end
    row:_fire("OnHyperlinkClick", "item:2581", "[Heavy Linen Bandage]", "LeftButton")
    T.eq(W.itemRef[1], "item:2581")
end)

T.it("closing a conversation from the rail menu", function()
    local G, W, ns, UI = load()
    whisper(W, "a", "Aaa")
    whisper(W, "b", "Bbb")
    ns.Rail.badges[2]:Click("RightButton")
    local menu = ns.W.CurrentMenu()
    local closeRow
    for _, r in ipairs(menu.rows) do if r:IsShown() and r.label:GetText() == "Close conversation" then closeRow = r end end
    T.ok(closeRow, "menu entry")
    closeRow:Click()
    T.no(ns.Store.Get("aaa").open)
    T.eq(#ns.Rail.badges, 1)
end)

T.it("slash command toggles, opens settings and resets", function()
    local G, W, ns, UI = load()
    G.SlashCmdList.SOTTO("")
    T.ok(UI.IsShown())
    G.SlashCmdList.SOTTO("")
    T.no(UI.IsShown())
    G.SlashCmdList.SOTTO("settings")
    T.eq(UI.View(), "settings")
    G.SottoDB.window.x = 900
    G.SlashCmdList.SOTTO("reset")
    T.eq(G.SottoDB.window.x, 22)
end)

T.it("the second reply binding opens the last person you whispered", function()
    local G, W, ns, UI = load()
    ns.Set("openOn", "never")
    W.combat = true
    W.chat("CHAT_MSG_WHISPER_INFORM", W.whisperArgs("hi", "Bbb"))
    W.chat("CHAT_MSG_WHISPER", W.whisperArgs("a", "Aaa"))
    W.combat = false
    G.Sotto_BindingReplySent()
    T.eq(UI.Active().key, "bbb")
    T.eq(W.focus, ns.Compose.box)
end)

T.it("the reply binding opens the last whisper with focus", function()
    local G, W, ns, UI = load()
    ns.Set("openOn", "never")
    whisper(W, "a", "Aaa")
    G.Sotto_BindingReply()
    T.ok(UI.IsShown())
    T.eq(UI.Active().key, "aaa")
    T.eq(W.focus, ns.Compose.box)
end)

T.it("the More menu stays inside the window", function()
    local G, W, ns, UI = load()
    whisper(W, "a", "Tarin Ashgrove")
    UI.header.more:Click()
    local menu = ns.W.CurrentMenu()
    T.ok(menu:IsShown(), "menu open")
    T.ok(menu:GetRight() <= UI.win:GetRight() + 0.01, "right edge inside the window")
end)

T.it("starting a closed conversation again reopens it", function()
    local G, W, ns, UI = load()
    local c = ns.Store.Ensure("w", "Aaa")
    ns.Store.Add(c, "i", "x")
    ns.Store.Close(c)
    UI.Open(c)
    T.ok(c.open, "open again")
    local found = false
    for _, b in ipairs(ns.Rail.badges) do if b.conv == c then found = true end end
    T.ok(found, "badge in the rail")
end)

T.it("closing the active conversation releases the compose box", function()
    local G, W, ns, UI = load()
    local a, b = ns.Store.Ensure("w", "Aaa"), ns.Store.Ensure("w", "Bbb")
    ns.Store.Add(a, "i", "x")
    ns.Store.Add(b, "i", "y")
    UI.Open(a, { focus = true })
    ns.Store.Close(a)
    T.no(W.focus, "keyboard released")
    T.eq(UI.Active(), b)
end)

T.it("showing the window marks the active conversation read and clears toasts", function()
    local G, W, ns, UI = load()
    whisper(W, "a", "Aaa")
    UI.Hide()
    W.combat = true
    whisper(W, "b", "Aaa")
    T.eq(#ns.Toast.active, 1)
    T.eq(ns.Store.Get("aaa").unread, 1)
    UI.Toggle()
    T.eq(ns.Store.Get("aaa").unread, 0)
    T.eq(#ns.Toast.active, 0)
end)

T.it("Enter releases the keyboard in combat and outside rested areas", function()
    local G, W, ns, UI = load()
    UI.Open(ns.Store.Ensure("w", "Aaa"), { focus = true })
    local box = ns.Compose.box
    W.resting = false
    box:SetText("one")
    box:_fire("OnEnterPressed")
    T.no(W.focus, "released in the open world")
    W.resting = true
    box:SetFocus()
    box:SetText("two")
    box:_fire("OnEnterPressed")
    T.eq(W.focus, box, "kept in a city or inn")
    W.combat = true
    box:SetText("three")
    box:_fire("OnEnterPressed")
    T.no(W.focus, "released in combat")
end)

T.it("the minimap button leaves EllesmereUI's hiding alone", function()
    local G, W, ns, UI = load()
    ns.Set("openOn", "never")
    G.SottoMinimapButton:Hide()
    whisper(W, "a", "Aaa")
    T.no(G.SottoMinimapButton:IsShown(), "still hidden")
    T.eq(G.SottoMinimapButton.count:GetText(), "1", "count updated")
end)

T.it("contact refreshes are batched and skipped while the window is hidden", function()
    local G, W, ns, UI = load()
    local calls = 0
    local orig = G.C_FriendList.GetFriendInfo
    G.C_FriendList.GetFriendInfo = function(...) calls = calls + 1; return orig(...) end
    for i = 1, 30 do ns.Store.Add(ns.Store.Ensure("w", "Name" .. i), "i", "x", G.time() - i) end
    calls = 0
    for _ = 1, 5 do W.fire("FRIENDLIST_UPDATE") end
    W.advance(2)
    T.eq(calls, 0, "nothing while hidden")
    UI.Toggle()
    calls = 0
    for _ = 1, 5 do W.fire("FRIENDLIST_UPDATE") end
    W.advance(2)
    T.ok(calls > 0 and calls <= 10, "one batched pass over the visible conversations: " .. calls)
end)

T.it("tooltip previews never cut a character in half", function()
    local G, W, ns, UI = load()
    local c = ns.Store.Ensure("w", "Aaa")
    for n = 55, 70 do
        ns.Store.Add(c, "i", string.rep("a", n) .. "ääääääääää")
        local p = ns.Rail.Preview(c)
        T.no(p:find("[\192-\255]$") or p:find("[\192-\255][\1-\127]") or p:find("[\192-\255]…"), "broken UTF-8 at " .. n)
    end
end)

T.it("+ starts a conversation in Sotto without Blizzard's chat box", function()
    local G, W, ns, UI = load()
    UI.Toggle()
    ns.Rail.plus:Click()
    local prompt = UI.prompt
    T.ok(prompt and prompt:IsShown(), "name field shown")
    T.eq(W.focus, prompt.edit, "focused")
    prompt.edit:SetText("tarin ashgrove")
    prompt.edit:_fire("OnEnterPressed")
    T.no(prompt:IsShown(), "name field closed")
    T.eq(UI.Active().key, "tarin ashgrove")
    T.eq(W.focus, ns.Compose.box, "ready to type")
    T.no(G.ChatFrame1EditBox:IsShown(), "Blizzard's chat box untouched")
end)

T.it("the name field takes the spelling of a friend and capitalises the rest", function()
    local G, W, ns, UI = load({ setup = function(G, W)
        W.friends = { { name = "Tarin Ashgrove", level = 34, className = "Warrior", connected = true } }
    end })
    UI.Toggle()
    ns.Rail.plus:Click()
    UI.prompt.edit:SetText("tarin ashgrove")
    UI.prompt.edit:_fire("OnEnterPressed")
    T.eq(UI.Active().name, "Tarin Ashgrove")
    ns.Rail.plus:Click()
    UI.prompt.edit:SetText("kaja stormhoof")
    UI.prompt.edit:_fire("OnEnterPressed")
    T.eq(UI.Active().name, "Kaja Stormhoof")
end)

T.it("Esc closes the name field", function()
    local G, W, ns, UI = load()
    UI.Toggle()
    ns.Rail.plus:Click()
    UI.prompt.edit:_fire("OnEscapePressed")
    T.no(UI.prompt:IsShown())
    T.no(W.focus)
end)

T.it("invite invites the contact", function()
    local G, W, ns, UI = load()
    whisper(W, "a", "Tarin Ashgrove")
    UI.header.invite:Click()
    T.eq(W.invited, "Tarin Ashgrove")
end)

T.it("the window fades when idle and wakes on a new message", function()
    local G, W, ns, UI = load()
    whisper(W, "a", "Aaa")
    T.eq(UI.win:GetAlpha(), 1)
    for _ = 1, 30 do W.advance(0.25) end
    T.ok(UI.win:GetAlpha() < 0.6, "faded: " .. UI.win:GetAlpha())
    whisper(W, "b", "Aaa")
    for _ = 1, 8 do W.advance(0.05) end
    T.ok(UI.win:GetAlpha() > 0.9, "awake: " .. UI.win:GetAlpha())
end)

T.it("no fading with the setting off or while typing", function()
    local G, W, ns, UI = load()
    ns.Set("fadeIdle", false)
    whisper(W, "a", "Aaa")
    for _ = 1, 30 do W.advance(0.25) end
    T.eq(UI.win:GetAlpha(), 1)
    ns.Set("fadeIdle", true)
    ns.Compose.box:SetFocus()
    for _ = 1, 30 do W.advance(0.25) end
    T.eq(UI.win:GetAlpha(), 1)
end)

T.it("dragging saves the position", function()
    local G, W, ns, UI = load()
    UI.Open(ns.Store.Ensure("w", "Aaa"))
    local win = UI.win
    win:ClearAllPoints()
    win:SetPoint("BOTTOMLEFT", G.UIParent, "BOTTOMLEFT", 300, 200)
    UI.SavePosition()
    T.eq(G.SottoDB.window.x, 300)
    T.eq(G.SottoDB.window.y, 200)
end)

T.it("rows stay inside the log after a resize", function()
    local G, W, ns, UI = load()
    local c = ns.Store.Ensure("w", "Aaa")
    for i = 1, 30 do ns.Store.Add(c, "i", "message number " .. i .. " with some words in it", G.time() - 3000 + i * 30) end
    UI.Open(c)
    UI.win:SetSize(360, 240)
    UI.win:_fire("OnSizeChanged", 360, 240)
    local logLeft = ns.Log.frame:GetLeft()
    local logRight = ns.Log.frame:GetRight()
    for _, r in ipairs(ns.Log.rows) do
        T.ok(r:GetLeft() >= logLeft - 0.5 and r:GetRight() <= logRight + 0.5, "row within the log")
    end
    T.ok(#ns.Log.rows < 30, "only visible rows are drawn")
end)

T.it("the empty view shows when there is nothing to show", function()
    local G, W, ns, UI = load()
    UI.Toggle()
    T.eq(UI.View(), "empty")
end)
