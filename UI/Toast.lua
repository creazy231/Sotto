-------------------------------------------------------------------------------
--  Sotto: notification cards for whispers that do not open the window (in
--  combat, or with "Open the window" set to Never). One card per
--  conversation ("+N" counts the rest), at most three, stacked upward from
--  the window's bottom-left corner, at its scale (the Scale setting). They
--  last 8 s; hovering pauses them.
--  Left click opens the conversation ready to type, right click dismisses.
-------------------------------------------------------------------------------
local _, ns = ...
local Ts = {}
ns.Toast = Ts

local W, L = ns.W, ns.L
local MAX, LIFE, GAP = 3, 8, 8

Ts.active = {}
local pool = {}

local function anchor()
    local g = ns.DB and ns.DB.window
    return (g and g.x) or 22, (g and g.y) or 328
end

-- The corner is in UIParent's units, a card's offsets in its own (they grow
-- with its scale): the corner is divided by the scale, the stacking is not.
local function layout()
    local x, y = anchor()
    local s = W.Scale()
    for i, t in ipairs(Ts.active) do
        t:ClearAllPoints()
        t:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x / s, y / s + (i - 1) * (t:GetHeight() + GAP))
    end
end

local function startTimer(t, seconds)
    if t.timer then t.timer:Cancel() end
    t.timer = C_Timer.NewTimer(seconds, function() Ts.Dismiss(t) end)
end

local function create()
    local t = W.Scaled(CreateFrame("Button", nil, UIParent))
    t:SetSize(308, 58)
    t:SetFrameStrata("DIALOG")
    t:SetClampedToScreen(true)
    t:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    t.bg = W.Fill(t, "panel")
    t.bg:SetAllPoints()
    W.Border(t, "hair")
    W.Outline(t, "edge")
    W.Shadow(t, 14, 0.55)
    t.bar = W.Fill(t, "accent", "ARTWORK")
    t.bar:SetPoint("TOPLEFT")
    t.bar:SetPoint("BOTTOMLEFT")
    t.bar:SetWidth(2)

    local tile = CreateFrame("Frame", nil, t)
    tile:SetSize(32, 32)
    tile:SetPoint("TOPLEFT", 10, -9)
    tile.bg = W.Fill(tile, "panelAlt")
    tile.bg:SetAllPoints()
    W.Outline(tile, "black")
    t.icon = tile:CreateTexture(nil, "ARTWORK")
    t.icon:SetAllPoints()
    t.initials = W.Text(tile, "bold", "bn")
    t.initials:SetPoint("CENTER", 0, 1)
    t.tile = tile

    t.name = W.Text(t, "bold", "text")
    t.name:SetPoint("TOPLEFT", tile, "TOPRIGHT", 9, 0)
    t.time = W.Text(t, "time", "muted")
    t.time:SetPoint("TOPRIGHT", -10, -10)
    t.time:SetText(L["now"])
    t.preview = W.Text(t, "small", "dim")
    t.preview:SetPoint("TOPLEFT", t.name, "BOTTOMLEFT", 0, -2)
    t.preview:SetPoint("RIGHT", t, "RIGHT", -10, 0)
    t.hint = W.Text(t, "hint", "faint")
    t.hint:SetPoint("TOPLEFT", t.preview, "BOTTOMLEFT", 0, -3)
    t.hint:SetText(L["Click to reply · right-click to dismiss"])
    t.count = W.Text(t, "badge", "accent")
    t.count:SetPoint("BOTTOMRIGHT", -8, 8)

    local ag = t:CreateAnimationGroup()
    local move = ag:CreateAnimation("Translation")
    move:SetOffset(0, 8)
    move:SetDuration(0.3)
    move:SetSmoothing("OUT")
    local fade = ag:CreateAnimation("Alpha")
    fade:SetFromAlpha(0)
    fade:SetToAlpha(1)
    fade:SetDuration(0.3)
    t.intro = ag

    t:SetScript("OnClick", function(self, button)
        local conv = self.conv
        Ts.Dismiss(self)
        if button == "LeftButton" and conv then ns.UI.Open(conv, { focus = true }) end
    end)
    t:SetScript("OnEnter", function(self)
        if self.timer then self.timer:Cancel(); self.timer = nil end
    end)
    t:SetScript("OnLeave", function(self) startTimer(self, 3) end)
    return t
end

local function fill(t, conv, msg)
    t.conv = conv
    t.name:SetText(ns.Contacts.Name(conv))
    local r, g, b = ns.Contacts.Color(conv)
    W.SetTextColor(t.name, { r, g, b })
    local icon = ns.Contacts.Icon(conv)
    if icon then
        if icon.atlas then
            t.icon:SetAtlas(icon.atlas)
        else
            t.icon:SetTexture(icon.texture)
            t.icon:SetTexCoord(icon.coords[1], icon.coords[2], icon.coords[3], icon.coords[4])
        end
        t.icon:Show()
        t.initials:Hide()
    else
        t.icon:Hide()
        t.initials:SetText(ns.Contacts.Initials(conv))
        t.initials:Show()
    end
    t.preview:SetText(ns.Format.Plain(msg and msg.m or ""))
end

function Ts.Show(conv, msg)
    if not conv then return end
    for _, t in ipairs(Ts.active) do
        if t.conv == conv then
            t.extra = t.extra + 1
            t.count:SetText("+" .. t.extra)
            t.count:Show()
            t.preview:SetText(ns.Format.Plain(msg and msg.m or ""))
            startTimer(t, LIFE)
            return t
        end
    end
    if #Ts.active >= MAX then Ts.Dismiss(Ts.active[1]) end
    local t = table.remove(pool) or create()
    t.extra = 0
    t.count:Hide()
    fill(t, conv, msg)
    Ts.active[#Ts.active + 1] = t
    layout()
    t:Show()
    t.intro:Play()
    startTimer(t, LIFE)
    return t
end

function Ts.Dismiss(t)
    if not t then return end
    if t.timer then t.timer:Cancel(); t.timer = nil end
    for i, x in ipairs(Ts.active) do
        if x == t then
            table.remove(Ts.active, i)
            t:Hide()
            t.conv = nil
            pool[#pool + 1] = t
            break
        end
    end
    layout()
end

function Ts.HideAll()
    for i = #Ts.active, 1, -1 do Ts.Dismiss(Ts.active[i]) end
end

function Ts.HideFor(conv)
    for i = #Ts.active, 1, -1 do
        if Ts.active[i].conv == conv then Ts.Dismiss(Ts.active[i]) end
    end
end

ns.Listen("SCALE_CHANGED", layout)
