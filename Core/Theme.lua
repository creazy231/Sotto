-------------------------------------------------------------------------------
--  Sotto: the look. Polestar's "EllesmereUI" scheme rebuilt from
--  EllesmereUI's live panel colour: the grounds are that colour moved in OKLab
--  lightness (sidebar -0.03, footer -0.02, panel +0.02, panelAlt +0.055,
--  sky +0.09), the text ladder is Polestar's graphite one, hairlines and
--  washes are white at low alpha. The accent is the player's class colour
--  (lifted until it reads at 4.5:1 on the panel) or EllesmereUI's accent.
--  EllesmereUI is read only through its skinning API (RegisterSkin getters,
--  OnLooksChanged); without it the same palette comes from EUI's defaults.
-------------------------------------------------------------------------------
local _, ns = ...
local Th = {}
ns.Theme = Th

local P = {}
Th.P = P

local S -- EllesmereUI's skin facade, once its callback ran

local DEFAULT_PANEL = { 0.08, 0.08, 0.08, 0.92 }
local DERIVE = { sidebar = -0.03, footer = -0.02, bg = 0, panel = 0.02, panelAlt = 0.055, sky = 0.09 }
local FIXED = {
    text = { 0.974, 0.974, 0.974, 1 }, dim = { 0.793, 0.801, 0.813, 1 }, muted = { 0.635, 0.646, 0.663, 1 },
    faint = { 0.435, 0.447, 0.467, 1 },
    hair = { 1, 1, 1, 0.10 }, hairSoft = { 1, 1, 1, 0.06 }, hover = { 1, 1, 1, 0.07 }, selected = { 1, 1, 1, 0.11 },
    track = { 1, 1, 1, 0.16 }, chip = { 1, 1, 1, 0.07 }, scroll = { 1, 1, 1, 0.16 },
    inset = { 0.039, 0.039, 0.039, 0.85 }, euiBorder = { 0.2, 0.2, 0.2, 1 }, shadow = { 0, 0, 0, 0.55 },
    black = { 0, 0, 0, 1 }, white = { 1, 1, 1, 1 },
    success = { 0.42, 0.85, 0.6, 1 }, warning = { 0.98, 0.75, 0.3, 1 }, warningText = { 0.914, 0.863, 0.753, 1 },
    danger = { 0.96, 0.45, 0.45, 1 }, link = { 0.58, 0.79, 1, 1 }, quest = { 1, 0.82, 0, 1 },
    offline = { 0.42, 0.43, 0.45, 1 },
}
local DEFAULT_ACCENT = { 1, 0.49, 0.04 } -- druid orange, used before the class is known

local REGULAR_FALLBACK = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
local fonts = { regular = REGULAR_FALLBACK, bold = REGULAR_FALLBACK }

local ROLES = {
    body = { "regular", 0 }, label = { "regular", 0 }, small = { "regular", -1 }, meta = { "regular", -2 },
    hint = { "regular", -2 }, time = { "regular", -3 }, section = { "regular", -3 },
    bold = { "bold", -0.5 }, name = { "bold", 1 }, title = { "bold", 1 }, badge = { "bold", -3 },
    big = { "bold", 2 },
}

local classCache = {}

local function copy(c) return { c[1], c[2], c[3], c[4] or 1 } end

local function euiCall(name)
    if not (S and S[name]) then return nil end
    local ok, a, b, c, d = pcall(S[name])
    if not ok or a == nil then return nil end
    return a, b, c, d
end

local function rawClassColor(file)
    local c = (C_ClassColor and C_ClassColor.GetClassColor and C_ClassColor.GetClassColor(file))
        or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[file])
    if c and type(c.r) == "number" then return c.r, c.g, c.b end
end

-- A class colour that reads at 4.5:1 on the panel. -> r, g, b
function Th.ClassColor(file)
    if not file then return P.text[1], P.text[2], P.text[3] end
    local cached = classCache[file]
    if cached then return cached[1], cached[2], cached[3] end
    local r, g, b = rawClassColor(file)
    if not r then return P.text[1], P.text[2], P.text[3] end
    r, g, b = ns.Color.Lift(P.panel, P.text, { r, g, b }, 4.5)
    classCache[file] = { r, g, b }
    return r, g, b
end

local function resolveAccent()
    if ns.Get("accent") == "eui" then
        local r, g, b = euiCall("GetAccentColor")
        if type(r) == "number" then return { r, g, b, 1 } end
    end
    local _, file = UnitClass("player")
    if file and rawClassColor(file) then
        local r, g, b = Th.ClassColor(file)
        return { r, g, b, 1 }
    end
    local r, g, b = ns.Color.Lift(P.panel, P.text, DEFAULT_ACCENT, 4.5)
    return { r, g, b, 1 }
end

local function resolveFonts()
    local path = euiCall("GetFont")
    if type(path) ~= "string" or path == "" then path = REGULAR_FALLBACK end
    fonts.regular = path
    -- EllesmereUI ships "Expressway Bold.ttf" next to "Expressway.TTF".
    local dir = path:match("^(.*[\\/])[Ee]xpressway%.[Tt][Tt][Ff]$")
    fonts.bold = dir and (dir .. "Expressway Bold.ttf") or path
end

function Th.Refresh()
    local pr, pg, pb, pa = euiCall("GetPanelColor")
    local base
    if type(pr) == "number" then
        base = { pr, pg, pb, type(pa) == "number" and pa or 1 }
    else
        base = copy(DEFAULT_PANEL)
    end
    for name, dL in pairs(DERIVE) do
        P[name] = ns.Color.Shift(base, dL, name == "sky" and 1.6 or 1)
    end
    P.bg[4] = base[4]
    P.sidebar[4] = math.min(1, base[4] + 0.05)
    P.panel[4] = 0.98
    P.footer[4], P.panelAlt[4], P.sky[4] = 1, 1, 1
    for name, c in pairs(FIXED) do P[name] = copy(c) end
    local bn = FRIENDS_BNET_NAME_COLOR
    P.bn = bn and { bn.r, bn.g, bn.b, 1 } or { 0.51, 0.773, 1, 1 }

    for k in pairs(classCache) do classCache[k] = nil end
    P.accent = resolveAccent()
    local dark = { 0.051, 0.051, 0.059, 1 }
    P.onAccent = ns.Color.Contrast(P.text, P.accent) > ns.Color.Contrast(dark, P.accent) and copy(P.text) or dark
    local a = P.accent
    P.focus = { a[1], a[2], a[3], 0.8 }         -- focused input border
    P.accentLine = { a[1], a[2], a[3], 0.55 }   -- the "New" divider
    P.accentWash = { a[1], a[2], a[3], 0.13 }   -- haze, notices
    P.accentBorder = { a[1], a[2], a[3], 0.32 }
    local w = P.warning
    P.warnBg = { w[1], w[2], w[3], 0.09 }
    P.warnLine = { w[1], w[2], w[3], 0.35 }
    P.edge = { 0, 0, 0, 0.75 }                  -- 1 px outside every window

    resolveFonts()
    ns.Format.linkColor = ns.Color.Hex(P.link[1], P.link[2], P.link[3])
    ns.Fire("LOOKS_CHANGED")
end

function Th.Color(name)
    local c = P[name] or P.text
    return c[1], c[2], c[3], c[4]
end

function Th.Accent()
    return P.accent[1], P.accent[2], P.accent[3]
end

-- "ffrrggbb" for |c escapes.
function Th.Hex(name)
    local c = P[name] or P.text
    return ns.Color.Hex(c[1], c[2], c[3])
end

-- -> path, size, flags
function Th.Font(role)
    local spec = ROLES[role] or ROLES.body
    local size = math.max(8, (ns.Get("fontSize") or 13) + spec[2])
    return fonts[spec[1]], size, ""
end

-- Font, no outline, a 1 px shadow (EllesmereUI's no-outline look). A bold
-- file the client cannot load falls back to the regular font.
function Th.ApplyFont(fs, role)
    local path, size, flags = Th.Font(role)
    if not fs:SetFont(path, size, flags) then
        if not fs:SetFont(fonts.regular, size, flags) then fs:SetFont(REGULAR_FALLBACK, size, flags) end
    end
    fs:SetShadowOffset(1, -1)
    fs:SetShadowColor(0, 0, 0, 0.6)
end

-------------------------------------------------------------------------------
--  Wiring
-------------------------------------------------------------------------------
Th.Refresh()

ns.On("PLAYER_LOGIN", function() Th.Refresh() end)

ns.Listen("SETTING_CHANGED", function(key)
    if key == "accent" or key == "fontSize" then Th.Refresh() end
end)

if EllesmereUI and EllesmereUI.RegisterSkin then
    pcall(EllesmereUI.RegisterSkin, "Sotto", function(skin)
        S = skin
        if S.OnLooksChanged then S.OnLooksChanged(function() Th.Refresh() end) end
        Th.Refresh()
    end)
end
