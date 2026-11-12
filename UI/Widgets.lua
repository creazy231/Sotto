-------------------------------------------------------------------------------
--  Sotto: drawing primitives and controls, all painted from the theme and
--  repainted on LOOKS_CHANGED. Flat fills, 1 px hairlines (one physical
--  pixel at any UI scale), white glyphs tinted in code, the house controls of
--  the settings view (switch, segmented choice, dropdown + menu, slider).
-------------------------------------------------------------------------------
local _, ns = ...
local W = {}
ns.W = W

local MEDIA = "Interface\\AddOns\\Sotto\\Media\\"
W.MEDIA = MEDIA
local CIRCLE = MEDIA .. "circle"
local PILL = MEDIA .. "pill"

local floor, ceil, max, min = math.floor, math.ceil, math.max, math.min

local function color(name) return ns.Theme.Color(name) end

-------------------------------------------------------------------------------
--  Repaint registry
-------------------------------------------------------------------------------
local painters = setmetatable({}, { __mode = "k" })

function W.Paint(obj, fn)
    painters[obj] = fn
    fn(obj)
    return obj
end

local function repaintAll()
    for obj, fn in pairs(painters) do fn(obj) end
end
ns.Listen("LOOKS_CHANGED", repaintAll)
ns.On("UI_SCALE_CHANGED", repaintAll)
ns.On("DISPLAY_SIZE_CHANGED", repaintAll)

-- One physical pixel in `frame` units.
function W.Pixel(frame)
    local _, h = GetPhysicalScreenSize()
    local scale = (frame and frame:GetEffectiveScale()) or 1
    if not h or h <= 0 or scale <= 0 then return 1 end
    return 768 / h / scale
end

-------------------------------------------------------------------------------
--  Regions
-------------------------------------------------------------------------------
local fillColor = setmetatable({}, { __mode = "k" })

function W.Fill(parent, colorName, layer, sub)
    local t = parent:CreateTexture(nil, layer or "BACKGROUND", nil, sub or 0)
    fillColor[t] = colorName
    W.Paint(t, function(tex) tex:SetColorTexture(color(fillColor[tex])) end)
    return t
end

function W.SetFill(tex, colorName)
    fillColor[tex] = colorName
    tex:SetColorTexture(color(colorName))
end

-- A 1 px line along one edge of `parent`, inset a and b at its ends.
function W.Hair(parent, edge, colorName, a, b, layer)
    local t = parent:CreateTexture(nil, layer or "BORDER", nil, 1)
    fillColor[t] = colorName or "hair"
    a, b = a or 0, b or 0
    W.Paint(t, function(tex)
        tex:SetColorTexture(color(fillColor[tex]))
        local px = W.Pixel(parent)
        tex:ClearAllPoints()
        if edge == "TOP" or edge == "BOTTOM" then
            tex:SetPoint(edge .. "LEFT", parent, edge .. "LEFT", a, 0)
            tex:SetPoint(edge .. "RIGHT", parent, edge .. "RIGHT", -b, 0)
            tex:SetHeight(px)
        else
            tex:SetPoint("TOP" .. edge, parent, "TOP" .. edge, 0, -a)
            tex:SetPoint("BOTTOM" .. edge, parent, "BOTTOM" .. edge, 0, b)
            tex:SetWidth(px)
        end
    end)
    return t
end

-- Four hairlines just outside the frame's edges (the dark rim of a window).
function W.Outline(frame, colorName)
    local lines = {}
    for i, edge in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        local t = frame:CreateTexture(nil, "BACKGROUND", nil, -6)
        fillColor[t] = colorName or "edge"
        lines[i] = W.Paint(t, function(tex)
            tex:SetColorTexture(color(fillColor[tex]))
            local px = W.Pixel(frame)
            tex:ClearAllPoints()
            if edge == "TOP" then
                tex:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", -px, 0)
                tex:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", px, 0)
                tex:SetHeight(px)
            elseif edge == "BOTTOM" then
                tex:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", -px, 0)
                tex:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", px, 0)
                tex:SetHeight(px)
            elseif edge == "LEFT" then
                tex:SetPoint("TOPRIGHT", frame, "TOPLEFT", 0, 0)
                tex:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT", 0, 0)
                tex:SetWidth(px)
            else
                tex:SetPoint("TOPLEFT", frame, "TOPRIGHT", 0, 0)
                tex:SetPoint("BOTTOMLEFT", frame, "BOTTOMRIGHT", 0, 0)
                tex:SetWidth(px)
            end
        end)
    end
    return lines
end

-- Four hairlines just inside the frame's edges.
function W.Border(frame, colorName, layer)
    return {
        W.Hair(frame, "TOP", colorName, 0, 0, layer), W.Hair(frame, "BOTTOM", colorName, 0, 0, layer),
        W.Hair(frame, "LEFT", colorName, 0, 0, layer), W.Hair(frame, "RIGHT", colorName, 0, 0, layer),
    }
end

local textColor = setmetatable({}, { __mode = "k" })
local textRole = setmetatable({}, { __mode = "k" })

function W.Text(parent, role, colorName, layer)
    local fs = parent:CreateFontString(nil, layer or "OVERLAY")
    textRole[fs] = role or "body"
    textColor[fs] = colorName or "text"
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(false)
    W.Paint(fs, function(f)
        ns.Theme.ApplyFont(f, textRole[f])
        if textColor[f] then f:SetTextColor(color(textColor[f])) end
    end)
    return fs
end

-- colorName may be a theme name or a { r, g, b } table (class colours).
function W.SetTextColor(fs, colorName)
    textColor[fs] = type(colorName) == "string" and colorName or nil
    if type(colorName) == "table" then
        fs:SetTextColor(colorName[1], colorName[2], colorName[3], colorName[4] or 1)
    else
        fs:SetTextColor(color(colorName))
    end
end

function W.SetRole(fs, role)
    textRole[fs] = role
    ns.Theme.ApplyFont(fs, role)
end

local iconColor = setmetatable({}, { __mode = "k" })

function W.Icon(parent, name, size, colorName, layer)
    local t = parent:CreateTexture(nil, layer or "ARTWORK")
    t:SetTexture(name:find("\\", 1, true) and name or (MEDIA .. "Icons\\" .. name))
    t:SetSize(size, size)
    iconColor[t] = colorName or "dim"
    W.Paint(t, function(tex) tex:SetVertexColor(color(iconColor[tex])) end)
    return t
end

function W.SetIconColor(tex, colorName)
    iconColor[tex] = colorName
    tex:SetVertexColor(color(colorName))
end

-- A soft drop shadow around `frame` (9-slice of Media\shadow, 16 px corners).
function W.Shadow(frame, size, alpha)
    size, alpha = size or 14, alpha or 0.55
    local c = 0.25
    local function piece(l, r, t, b)
        local tex = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
        tex:SetTexture(MEDIA .. "shadow")
        tex:SetTexCoord(l, r, t, b)
        tex:SetVertexColor(0, 0, 0, alpha)
        return tex
    end
    local tl, tr, bl, br = piece(0, c, 0, c), piece(1 - c, 1, 0, c), piece(0, c, 1 - c, 1), piece(1 - c, 1, 1 - c, 1)
    tl:SetSize(size, size); tl:SetPoint("BOTTOMRIGHT", frame, "TOPLEFT")
    tr:SetSize(size, size); tr:SetPoint("BOTTOMLEFT", frame, "TOPRIGHT")
    bl:SetSize(size, size); bl:SetPoint("TOPRIGHT", frame, "BOTTOMLEFT")
    br:SetSize(size, size); br:SetPoint("TOPLEFT", frame, "BOTTOMRIGHT")
    local top, bottom = piece(c, 1 - c, 0, c), piece(c, 1 - c, 1 - c, 1)
    local left, right = piece(0, c, c, 1 - c), piece(1 - c, 1, c, 1 - c)
    top:SetPoint("BOTTOMLEFT", tl, "BOTTOMRIGHT"); top:SetPoint("TOPRIGHT", tr, "TOPLEFT")
    bottom:SetPoint("TOPLEFT", bl, "TOPRIGHT"); bottom:SetPoint("BOTTOMRIGHT", br, "BOTTOMLEFT")
    left:SetPoint("TOPRIGHT", tl, "BOTTOMRIGHT"); left:SetPoint("BOTTOMLEFT", bl, "TOPLEFT")
    right:SetPoint("TOPLEFT", tr, "BOTTOMLEFT"); right:SetPoint("BOTTOMRIGHT", br, "TOPRIGHT")
    return { tl, tr, bl, br, top, bottom, left, right }
end

-------------------------------------------------------------------------------
--  Tooltips (GameTooltip: EllesmereUI skins it)
-------------------------------------------------------------------------------
function W.Tip(owner, title, lines, anchor)
    GameTooltip:SetOwner(owner, anchor or "ANCHOR_TOP")
    GameTooltip:SetText(title, 1, 1, 1)
    if lines then
        for _, line in ipairs(lines) do
            if type(line) == "table" then
                GameTooltip:AddLine(line[1], line[2], line[3], line[4], true)
            else
                GameTooltip:AddLine(line, 0.79, 0.8, 0.81, true)
            end
        end
    end
    GameTooltip:Show()
end

function W.HideTip(owner)
    if GameTooltip:GetOwner() == owner then GameTooltip:Hide() end
end

-------------------------------------------------------------------------------
--  Buttons
-------------------------------------------------------------------------------
function W.IconButton(parent, icon, tip, onClick, size, glyph)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(size or 24, size or 24)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b.hover = W.Fill(b, "hover")
    b.hover:SetAllPoints()
    b.hover:Hide()
    b.icon = W.Icon(b, icon, glyph or 15, "dim")
    b.icon:SetPoint("CENTER")
    b.restColor = "dim"
    b:SetScript("OnEnter", function(self)
        self.hover:Show()
        W.SetIconColor(self.icon, self.activeColor or "text")
        if self.tip then W.Tip(self, self.tip) end
    end)
    b:SetScript("OnLeave", function(self)
        self.hover:Hide()
        W.SetIconColor(self.icon, self.activeColor or self.restColor)
        W.HideTip(self)
    end)
    b:SetScript("OnClick", function(self, button) if onClick then onClick(self, button) end end)
    b.tip = tip
    return b
end

-- A colored pill (badge, chip) of height h; width follows SetWidth.
function W.Pill(parent, h, colorName, layer)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(h, h)
    local l = f:CreateTexture(nil, layer or "ARTWORK")
    local m = f:CreateTexture(nil, layer or "ARTWORK")
    local r = f:CreateTexture(nil, layer or "ARTWORK")
    for _, t in ipairs({ l, m, r }) do t:SetTexture(CIRCLE) end
    l:SetTexCoord(0, 0.5, 0, 1); l:SetPoint("TOPLEFT"); l:SetPoint("BOTTOMLEFT"); l:SetWidth(h / 2)
    r:SetTexCoord(0.5, 1, 0, 1); r:SetPoint("TOPRIGHT"); r:SetPoint("BOTTOMRIGHT"); r:SetWidth(h / 2)
    m:SetTexCoord(0.49, 0.51, 0, 1); m:SetPoint("TOPLEFT", l, "TOPRIGHT"); m:SetPoint("BOTTOMRIGHT", r, "BOTTOMLEFT")
    f.parts = { l, m, r }
    f.colorName = colorName or "chip"
    function f:SetPillColor(name)
        self.colorName = name
        for _, t in ipairs(self.parts) do t:SetVertexColor(color(name)) end
    end
    W.Paint(f, function(self) self:SetPillColor(self.colorName) end)
    return f
end

-------------------------------------------------------------------------------
--  Switch
-------------------------------------------------------------------------------
function W.Switch(parent, get, set)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(26, 14)
    b.track = b:CreateTexture(nil, "ARTWORK")
    b.track:SetTexture(PILL)
    b.track:SetAllPoints()
    b.knob = b:CreateTexture(nil, "OVERLAY")
    b.knob:SetTexture(CIRCLE)
    b.knob:SetSize(10, 10)
    function b:Refresh()
        local on = get() and true or false
        if on then
            self.track:SetVertexColor(color("accent"))
            self.knob:SetVertexColor(color("white"))
        else
            self.track:SetVertexColor(color("track"))
            self.knob:SetVertexColor(color("dim"))
        end
        self.knob:ClearAllPoints()
        self.knob:SetPoint("LEFT", self, "LEFT", on and 14 or 2, 0)
    end
    b:SetScript("OnClick", function(self)
        local v = not get()
        set(v)
        PlaySound(v and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
        self:Refresh()
    end)
    W.Paint(b, function(self) self:Refresh() end)
    return b
end

-------------------------------------------------------------------------------
--  Segmented choice
-------------------------------------------------------------------------------
function W.Segmented(parent, choices, get, set)
    local f = CreateFrame("Frame", nil, parent)
    f.buttons = {}
    local x = 0
    for i, c in ipairs(choices) do
        local b = CreateFrame("Button", nil, f)
        b.value = c.value
        b.bg = W.Fill(b, "selected")
        b.bg:SetAllPoints()
        b.line = W.Fill(b, "accent", "ARTWORK")
        b.line:SetPoint("BOTTOMLEFT")
        b.line:SetPoint("BOTTOMRIGHT")
        b.line:SetHeight(2)
        b.text = W.Text(b, "small", "dim")
        b.text:SetText(c.text)
        b.text:SetPoint("CENTER", 0, 0)
        local w = ceil(b.text:GetStringWidth()) + 14
        b:SetSize(w, 20)
        b:SetPoint("LEFT", f, "LEFT", x, 0)
        if i > 1 then W.Hair(b, "LEFT") end
        b:SetScript("OnClick", function(self)
            set(self.value)
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
            f:Refresh()
        end)
        b:SetScript("OnEnter", function(self) if not self.selected then W.SetTextColor(self.text, "text") end end)
        b:SetScript("OnLeave", function(self) if not self.selected then W.SetTextColor(self.text, "dim") end end)
        x = x + w
        f.buttons[i] = b
    end
    f:SetSize(x, 20)
    W.Border(f)
    function f:Refresh()
        local v = get()
        for _, b in ipairs(self.buttons) do
            b.selected = b.value == v
            b.bg:SetShown(b.selected)
            b.line:SetShown(b.selected)
            W.SetTextColor(b.text, b.selected and "text" or "dim")
        end
    end
    f:Refresh()
    return f
end

-------------------------------------------------------------------------------
--  Menu (one shared frame)
-------------------------------------------------------------------------------
local menu

local function menuRow(i)
    local row = menu.rows[i]
    if row then return row end
    row = CreateFrame("Button", nil, menu)
    row:SetHeight(22)
    row.hover = W.Fill(row, "hover")
    row.hover:SetAllPoints()
    row.hover:Hide()
    row.label = W.Text(row, "small", "text")
    row.label:SetPoint("LEFT", 10, 0)
    row.check = W.Icon(row, "check", 12, "accent")
    row.check:SetPoint("RIGHT", -8, 0)
    row:SetScript("OnEnter", function(self) if not self.disabled then self.hover:Show() end end)
    row:SetScript("OnLeave", function(self) self.hover:Hide() end)
    row:SetScript("OnClick", function(self)
        if self.disabled then return end
        local fn = self.func
        W.CloseMenu()
        if fn then fn() end
    end)
    menu.rows[i] = row
    return row
end

local function buildMenu()
    menu = CreateFrame("Frame", "SottoMenu", UIParent)
    menu:SetFrameStrata("FULLSCREEN_DIALOG")
    menu:SetToplevel(true)
    menu:EnableMouse(true)
    menu:SetClampedToScreen(true)
    menu.bg = W.Fill(menu, "panel")
    menu.bg:SetAllPoints()
    W.Border(menu, "euiBorder")
    W.Shadow(menu, 10, 0.5)
    menu.rows = {}
    menu:Hide()
    menu:RegisterEvent("GLOBAL_MOUSE_DOWN")
    menu:SetScript("OnEvent", function(self)
        if self:IsShown() and not self:IsMouseOver() and not (self.anchor and self.anchor:IsMouseOver()) then
            self:Hide()
        end
    end)
    tinsert(UISpecialFrames, "SottoMenu")
end

-- items: { { text, func, checked, disabled, color } ... }
-- align "RIGHT" opens the menu leftwards from the anchor's right edge (for
-- anchors near the right edge of a window).
function W.Menu(anchor, items, width, align)
    if not menu then buildMenu() end
    if menu:IsShown() and menu.anchor == anchor then W.CloseMenu(); return menu end
    menu.anchor = anchor
    local widest = 0
    for i, item in ipairs(items) do
        local row = menuRow(i)
        row.label:SetText(item.text)
        W.SetTextColor(row.label, item.disabled and "faint" or (item.color or "text"))
        row.check:SetShown(item.checked and true or false)
        row.func, row.disabled = item.func, item.disabled
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", menu, "TOPLEFT", 1, -4 - (i - 1) * 22)
        row:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -1, -4 - (i - 1) * 22)
        row:Show()
        widest = max(widest, row.label:GetStringWidth())
    end
    for i = #items + 1, #menu.rows do menu.rows[i]:Hide() end
    menu:SetSize(max(width or 0, anchor:GetWidth(), ceil(widest) + 40), #items * 22 + 8)
    menu:ClearAllPoints()
    if align == "RIGHT" then
        menu:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -2)
    else
        menu:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
    end
    menu:Show()
    return menu
end

function W.CloseMenu()
    if menu then menu:Hide() end
end

function W.CurrentMenu() return menu end

-------------------------------------------------------------------------------
--  Dropdown
-------------------------------------------------------------------------------
function W.Dropdown(parent, choices, get, set)
    local b = CreateFrame("Button", nil, parent)
    b.bg = W.Fill(b, "inset")
    b.bg:SetAllPoints()
    W.Border(b, "euiBorder")
    b.label = W.Text(b, "small", "text")
    b.label:SetPoint("LEFT", 7, 0)
    b.chev = W.Icon(b, "chevron", 10, "muted")
    b.chev:SetPoint("RIGHT", -6, 0)
    local widest = 0
    for _, c in ipairs(choices) do
        b.label:SetText(c.text)
        widest = max(widest, b.label:GetStringWidth())
    end
    b:SetSize(ceil(widest) + 34, 20)
    function b:Refresh()
        local v = get()
        for _, c in ipairs(choices) do
            if c.value == v then self.label:SetText(c.text) return end
        end
        self.label:SetText(choices[1] and choices[1].text or "")
    end
    b:SetScript("OnClick", function(self)
        local items = {}
        local v = get()
        for _, c in ipairs(choices) do
            items[#items + 1] = { text = c.text, checked = c.value == v, func = function()
                set(c.value)
                self:Refresh()
            end }
        end
        W.Menu(self, items, nil, "RIGHT")
    end)
    b:SetScript("OnEnter", function(self) W.SetIconColor(self.chev, "text") end)
    b:SetScript("OnLeave", function(self) W.SetIconColor(self.chev, "muted") end)
    b:Refresh()
    return b
end

-------------------------------------------------------------------------------
--  Slider
-------------------------------------------------------------------------------
function W.Slider(parent, lo, hi, step, get, set)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(104, 14)
    f:EnableMouse(true)
    f:EnableMouseWheel(true)
    f.value = W.Text(f, "small", "dim")
    f.value:SetPoint("RIGHT", 0, 0)
    f.value:SetJustifyH("RIGHT")
    f.value:SetWidth(20)
    f.track = W.Fill(f, "track", "ARTWORK")
    f.track:SetPoint("LEFT", 5, 0)
    f.track:SetPoint("RIGHT", -30, 0)
    f.track:SetHeight(2)
    f.fill = W.Fill(f, "accent", "ARTWORK", 1)
    f.fill:SetPoint("LEFT", f.track, "LEFT")
    f.fill:SetHeight(2)
    f.knob = f:CreateTexture(nil, "OVERLAY")
    f.knob:SetTexture(CIRCLE)
    f.knob:SetSize(10, 10)
    W.Paint(f.knob, function(t) t:SetVertexColor(color("white")) end)

    local function clamp(v)
        v = floor((v - lo) / step + 0.5) * step + lo
        return max(lo, min(hi, v))
    end

    function f:Refresh()
        local v = get()
        local frac = (hi > lo) and (v - lo) / (hi - lo) or 0
        local w = self.track:GetWidth()
        self.fill:SetWidth(max(0.001, w * frac))
        self.knob:ClearAllPoints()
        self.knob:SetPoint("CENTER", self.track, "LEFT", w * frac, 0)
        self.value:SetText(tostring(v))
    end

    function f:SetTo(v)
        v = clamp(v)
        if v ~= get() then set(v) end
        self:Refresh()
    end

    local function fromCursor(self)
        local x = GetCursorPosition() / self:GetEffectiveScale()
        local left, w = self.track:GetLeft(), self.track:GetWidth()
        if not left or w <= 0 then return end
        self:SetTo(lo + (hi - lo) * max(0, min(1, (x - left) / w)))
    end

    f:SetScript("OnMouseWheel", function(self, delta) self:SetTo(get() + delta * step) end)
    f:SetScript("OnMouseDown", function(self)
        fromCursor(self)
        self:SetScript("OnUpdate", fromCursor)
    end)
    f:SetScript("OnMouseUp", function(self) self:SetScript("OnUpdate", nil) end)
    f:SetScript("OnSizeChanged", function(self) self:Refresh() end)
    W.Paint(f, function(self) self:Refresh() end)
    return f
end
