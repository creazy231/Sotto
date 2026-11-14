local T = T

-- The Scale setting (Settings, Look): the window, its menu, the notifications and the copy box at 50 to 200 %.

local function load(opts)
    local G, W, ns = T.load(opts)
    return G, W, ns, ns.UI
end

local function whisper(W, text, sender, o)
    W.chat("CHAT_MSG_WHISPER", W.whisperArgs(text, sender, o))
end

-- One physical pixel at a scale, in the fake's 1920 x 1080 screen.
local function pixel(scale) return 768 / 1080 / scale end

-- How thick the frame's own hairlines are: every texture on it thinner than two units.
local function hairs(frame)
    local list = {}
    for _, r in ipairs(frame._regions) do
        if r._type == "Texture" then
            local d = (r._h and r._h > 0 and r._h < 1.9 and r._h) or (r._w and r._w > 0 and r._w < 1.9 and r._w)
            if d then list[#list + 1] = d end
        end
    end
    return list
end

T.it("Settings has a Scale slider under Accent: 100 % to start, 50 to 200 % in steps of 5", function()
    local G, W, ns, UI = load()
    UI.ShowSettings()
    local C = ns.Settings.controls
    local slider = C.scale
    T.ok(slider, "a Scale control")
    T.eq(slider:GetParent().label:GetText(), "Scale")
    T.eq(slider.value:GetText(), "100%")
    local accent, scale, size = C.accent:GetParent(), slider:GetParent(), C.fontSize:GetParent()
    T.ok(accent:GetTop() > scale:GetTop() and scale:GetTop() > size:GetTop(), "between Accent and Text size")
    T.near(slider.track:GetLeft(), C.fontSize.track:GetLeft(), 1e-9, "its track lines up with Text size's")
    T.near(slider.track:GetRight(), C.fontSize.track:GetRight(), 1e-9)

    slider:SetTo(150)
    T.eq(ns.Get("scale"), 1.5)
    T.eq(slider.value:GetText(), "150%")
    T.eq(UI.win:GetScale(), 1.5, "the window follows at once")
    slider:_fire("OnMouseWheel", 1)
    T.near(ns.Get("scale"), 1.55, 1e-9, "a wheel notch: 5 %")
    slider:SetTo(97)
    T.near(ns.Get("scale"), 0.95, 1e-9, "in steps of 5")
    slider:SetTo(500)
    T.eq(ns.Get("scale"), 2, "200 % at most")
    T.eq(slider.value:GetText(), "200%")
    slider:SetTo(10)
    T.eq(ns.Get("scale"), 0.5, "50 % at least")
end)

T.it("a dragged Scale applies when the knob is let go", function()
    local G, W, ns, UI = load()
    UI.ShowSettings()
    local slider = ns.Settings.controls.scale
    -- The slider sits in the window it scales: applied at once, the window would grow under the cursor and the
    -- scale would chase itself.
    W.cursorX = slider.track:GetLeft() + 0.6 * slider.track:GetWidth()
    slider:_fire("OnMouseDown", "LeftButton")
    T.eq(slider.value:GetText(), "140%", "the knob follows the cursor")
    T.eq(ns.Get("scale"), 1, "the window waits")
    W.cursorX = slider.track:GetLeft() + 0.8 * slider.track:GetWidth()
    W.advance(0.1)
    T.eq(slider.value:GetText(), "170%")
    T.eq(UI.win:GetScale(), 1)
    slider:_fire("OnMouseUp", "LeftButton")
    T.near(ns.Get("scale"), 1.7, 1e-9, "let go: the scale applies")
    T.near(UI.win:GetScale(), 1.7, 1e-9)
    slider:_fire("OnMouseWheel", -1)
    T.near(ns.Get("scale"), 1.65, 1e-9, "the wheel still applies at once")
end)

T.it("the window keeps its bottom-left corner whatever the scale", function()
    local G, W, ns, UI = load({ db = {
        settings = { scale = 0.8 }, window = { point = "BOTTOMLEFT", x = 400, y = 300, w = 410, h = 306 },
    } })
    local win = UI.win
    T.eq(win:GetScale(), 0.8, "the saved scale from the start")
    local point, rel, relPoint, x, y = win:GetPoint(1)
    T.eq(point, "BOTTOMLEFT")
    T.eq(rel, G.UIParent)
    T.eq(relPoint, "BOTTOMLEFT")
    T.near(x * 0.8, 400, 1e-9, "the corner where it was saved, in UIParent's units")
    T.near(y * 0.8, 300, 1e-9)

    ns.Set("scale", 1.5)
    T.eq(win:GetScale(), 1.5, "a new scale applies at once")
    _, _, _, x, y = win:GetPoint(1)
    T.near(x * 1.5, 400, 1e-9, "and the corner stays put")
    T.near(y * 1.5, 300, 1e-9)
    T.eq(win:GetWidth(), 410, "the size stays in the window's own units")
    T.eq(win:GetHeight(), 306)

    -- Moved at 150 %: the game anchors it its own way, in the window's units; it is saved in UIParent's.
    UI.StartMoving()
    win:ClearAllPoints()
    win:SetPoint("BOTTOMLEFT", G.UIParent, "BOTTOMLEFT", 100, 50)
    UI.StopMoving()
    T.eq(ns.DB.window.x, 150)
    T.eq(ns.DB.window.y, 75)
    _, _, _, x, y = win:GetPoint(1)
    T.near(x, 100, 1e-9, "where it was let go")
    T.near(y, 50, 1e-9)

    ns.Set("scale", 1)
    _, _, _, x, y = win:GetPoint(1)
    T.eq(x, 150, "back at 100 %, the corner where it was moved to")
    T.eq(y, 75)
end)

T.it("a scale outside 50 to 200 % reads as 100 %", function()
    for _, bad in ipairs({ 5, 0.1, "big" }) do
        local G, W, ns, UI = load({ db = { settings = { scale = bad } } })
        T.eq(UI.win:GetScale(), 1, "scale " .. tostring(bad))
        UI.ShowSettings()
        T.eq(ns.Settings.controls.scale.value:GetText(), "100%")
    end
    local G, W, ns, UI = load({ db = { settings = { scale = 0 / 0 } } })
    T.eq(UI.win:GetScale(), 1, "not a number")
end)

T.it("notifications take the scale, stacked up from the window's corner", function()
    local G, W, ns, UI = load({ db = {
        settings = { scale = 1.5 }, window = { point = "BOTTOMLEFT", x = 30, y = 300, w = 410, h = 306 },
    } })
    W.combat = true
    whisper(W, "lf healer?", "Kaja Stormhoof")
    whisper(W, "inv?", "Tarin Ashgrove")
    local a, b = ns.Toast.active[1], ns.Toast.active[2]
    T.eq(a:GetScale(), 1.5)
    T.eq(b:GetScale(), 1.5)
    local _, rel, _, x, y = a:GetPoint(1)
    T.eq(rel, G.UIParent)
    T.near(x * 1.5, 30, 1e-9, "at the window's corner")
    T.near(y * 1.5, 300, 1e-9)
    local _, _, _, x2, y2 = b:GetPoint(1)
    T.near(x2, x, 1e-9)
    T.near(y2 - y, a:GetHeight() + 8, 1e-9, "the next one above it, 8 apart at its scale")
end)

T.it("menus open at the window's scale", function()
    local G, W, ns, UI = load({ db = { settings = { scale = 1.5 } } })
    UI.ShowSettings()
    ns.Settings.controls.keepDays:Click()
    local menu = ns.W.CurrentMenu()
    T.ok(menu and menu:IsShown(), "open")
    T.eq(menu:GetScale(), 1.5)
    menu:Hide()
    ns.Set("scale", 0.75)
    ns.Settings.controls.keepDays:Click()
    T.eq(menu:GetScale(), 0.75, "and at a new one")
end)

T.it("the copy box takes the scale", function()
    local G, W, ns, UI = load({ db = { settings = { scale = 1.25 } } })
    ns.CopyBox.Show("Copy", "a link")
    local f = ns.CopyBox.frame
    T.eq(f:GetScale(), 1.25)
    local point, rel, relPoint, x, y = f:GetPoint(1)
    T.eq(point, "CENTER")
    T.eq(rel, G.UIParent)
    T.eq(relPoint, "CENTER")
    T.eq(x, 0)
    T.near(y * 1.25, 120, 1e-9, "120 above the middle of the screen, as at 100 %")
    ns.Set("scale", 2)
    T.eq(f:GetScale(), 2)
    _, _, _, x, y = f:GetPoint(1)
    T.near(y * 2, 120, 1e-9)
end)

T.it("hairlines stay one physical pixel at a new scale", function()
    local G, W, ns, UI = load()
    UI.Show()
    W.combat = true
    UI.Hide()
    whisper(W, "a", "Aaa")
    local toast = ns.Toast.active[1]
    T.near(UI.header.vsep:GetWidth(), pixel(1), 1e-9)
    ns.Set("scale", 1.5)
    T.near(UI.header.vsep:GetWidth(), pixel(1.5), 1e-9, "the window's")
    local lines = hairs(toast)
    T.ok(#lines >= 4, "a notification's border")
    for _, d in ipairs(lines) do T.near(d, pixel(1.5), 1e-9, "a notification's") end
    ns.Toast.HideAll()
    whisper(W, "b", "Bbb")
    lines = hairs(ns.Toast.active[1])
    T.ok(#lines >= 4)
    for _, d in ipairs(lines) do T.near(d, pixel(1.5), 1e-9, "one shown after the change") end
end)

-- Logs in with the scale saved as `saved`. -> a counter of the repaints from PLAYER_LOGIN on (count() reads it,
-- count(0) sets it), and the client. The theme paints once at login itself.
local function loginRepaints(saved)
    local G, W, ns = T.load({ login = false, db = { settings = { scale = saved } } })
    local repaints = 0
    ns.Listen("LOOKS_CHANGED", function() repaints = repaints + 1 end)
    W.fire("PLAYER_LOGIN")
    return function(set)
        if set then repaints = set end
        return repaints
    end, G, W, ns
end

T.it("a scale only applies when it is new", function()
    local theme = loginRepaints(1)()
    local count, G, W, ns = loginRepaints(1.1)
    T.eq(count(), theme + 1, "a saved scale other than 100 % repaints once at login")
    T.eq(ns.UI.win:GetScale(), 1.1)
    count(0)
    ns.UI.Show()
    ns.UI.Hide()
    ns.UI.Show()
    T.eq(count(), 0, "opening at the saved scale repaints nothing")
    ns.Set("scale", 1.2)
    T.eq(count(), 1, "a new scale repaints, once")
    count(0)
    W.fire("PLAYER_LOGIN")
    T.eq(count(), theme, "the scale it has already: no repaint of its own")
end)
