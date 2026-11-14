local T = T

local function load()
    local G, W, ns = T.load()
    local parent = G.CreateFrame("Frame", nil, G.UIParent)
    parent:SetSize(300, 200)
    parent:SetPoint("CENTER")
    return G, W, ns, ns.W, parent
end

T.it("switch toggles its value and repaints", function()
    local G, W, ns, Wd, parent = load()
    local v = false
    local sw = Wd.Switch(parent, function() return v end, function(x) v = x end)
    local before = { sw.track:GetVertexColor() }
    sw:Click()
    T.eq(v, true)
    local after = { sw.track:GetVertexColor() }
    T.ok(before[1] ~= after[1] or before[4] ~= after[4], "track colour changed")
    sw:Click()
    T.eq(v, false)
end)

T.it("segmented control selects a choice", function()
    local G, W, ns, Wd, parent = load()
    local v = "a"
    local seg = Wd.Segmented(parent, { { value = "a", text = "Always" }, { value = "b", text = "Never" } },
        function() return v end, function(x) v = x end)
    T.ok(seg.buttons[1].selected, "first selected")
    seg.buttons[2]:Click()
    T.eq(v, "b")
    T.ok(seg.buttons[2].selected and not seg.buttons[1].selected, "selection moved")
    T.ok(seg:GetWidth() > 0, "sized to its labels")
end)

T.it("slider clamps and steps", function()
    local G, W, ns, Wd, parent = load()
    local v = 13
    local sl = Wd.Slider(parent, 11, 16, 1, function() return v end, function(x) v = x end)
    sl:SetTo(17.4)
    T.eq(v, 16)
    sl:SetTo(12.4)
    T.eq(v, 12)
    sl:_fire("OnMouseWheel", 1)
    T.eq(v, 13)
    sl:_fire("OnMouseWheel", -1)
    T.eq(v, 12)
    T.eq(sl.value:GetText(), "12")
end)

T.it("a slider shows its value through a format, with room for the widest", function()
    local G, W, ns, Wd, parent = load()
    local v = 100
    local sl = Wd.Slider(parent, 50, 200, 5, function() return v end, function(x) v = x end,
        function(x) return x .. "%" end)
    T.eq(sl.value:GetText(), "100%")
    sl.value:SetText("200%")
    local need = sl.value:GetStringWidth()
    sl:Refresh()
    T.ok(sl.room >= need, "room for 200%")
    T.near(sl.track:GetRight(), sl:GetRight() - 10 - sl.room, 1e-9, "the track ends 10 px before it")
    v = 50
    sl:Refresh()
    T.eq(sl.value:GetText(), "50%")
    T.eq(sl.value:GetWidth(), sl.value:GetStringWidth(), "the value as wide as its text: never cut off")
    T.eq(select(1, sl.value:GetPoint(1)), "RIGHT")
    local plain = Wd.Slider(parent, 11, 16, 1, function() return 13 end, function() end)
    T.eq(plain:GetWidth(), 104, "a slider without a format as before")
    T.eq(plain.room, 20)
    T.eq(plain.track:GetWidth(), sl.track:GetWidth(), "every track as long")
    local wide = Wd.Slider(parent, 11, 16, 1, function() return 13 end, function() end, nil, sl.room)
    T.eq(wide:GetWidth(), sl:GetWidth(), "given the other's room, as wide")
    T.eq(wide.value:GetText(), "13")
end)

T.it("dropdown opens a menu and sets the value", function()
    local G, W, ns, Wd, parent = load()
    local v = "chime"
    local dd = Wd.Dropdown(parent, { { value = "chime", text = "Soft chime" }, { value = "none", text = "None" } },
        function() return v end, function(x) v = x end)
    T.eq(dd.label:GetText(), "Soft chime")
    dd:Click()
    local menu = Wd.CurrentMenu()
    T.ok(menu and menu:IsShown(), "menu open")
    T.eq(#menu.rows >= 2 and menu.rows[2].label:GetText(), "None")
    menu.rows[2]:Click()
    T.eq(v, "none")
    T.no(menu:IsShown(), "menu closed")
    T.eq(dd.label:GetText(), "None")
end)

T.it("a right-aligned menu opens to the left of its anchor", function()
    local G, W, ns, Wd, parent = load()
    local anchor = G.CreateFrame("Button", nil, parent)
    anchor:SetSize(24, 24)
    anchor:SetPoint("TOPRIGHT", parent, "TOPRIGHT")
    local menu = Wd.Menu(anchor, { { text = "Copy conversation" }, { text = "Close conversation" } }, 170, "RIGHT")
    T.near(menu:GetRight(), anchor:GetRight(), 0.01, "right edges line up")
    T.ok(menu:GetLeft() < anchor:GetLeft(), "opens leftwards")
end)

T.it("text and fills repaint when the looks change", function()
    local G, W, ns, Wd, parent = load()
    local fill = Wd.Fill(parent, "accent")
    local fs = Wd.Text(parent, "body", "accent")
    ns.Set("accent", "eui")
    ns.Theme.P.accent = { 1, 0, 0, 1 } -- simulate a new accent, then repaint
    ns.Fire("LOOKS_CHANGED")
    T.eq(fill._color[1], 1)
    T.eq(select(1, fs:GetTextColor()), 1)
end)

T.it("icon buttons show a tooltip and click", function()
    local G, W, ns, Wd, parent = load()
    local clicked = false
    local b = Wd.IconButton(parent, "invite", "Invite to group", function() clicked = true end)
    b:_fire("OnEnter")
    T.eq(G.GameTooltip._lines[1], "Invite to group")
    b:_fire("OnLeave")
    b:Click()
    T.ok(clicked)
    T.ok(b.icon:GetTexture():find("Media\\Icons\\invite", 1, true), "icon path")
end)

T.it("Pixel is one physical pixel in frame units", function()
    local G, W, ns, Wd, parent = load()
    T.near(Wd.Pixel(parent), 768 / 1080, 1e-6)
end)
