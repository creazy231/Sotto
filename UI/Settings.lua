-------------------------------------------------------------------------------
--  Sotto: the settings view (the gear in the rail). Nine settings in four
--  sections, the rows of the approved mockup: label, a small description,
--  the control on the right, a faint line between rows. In WoW Forever's
--  gamepad interface a row above them says that the game's own chat is used.
-------------------------------------------------------------------------------
local _, ns = ...
local St = {}
ns.Settings = St

local W, L = ns.W, ns.L
local ceil, max = math.ceil, math.max

St.controls = {}
local view, scroll, content, thumb
local rows = {}

local CHIME = "Interface\\AddOns\\Sotto\\Media\\Sounds\\chime.ogg"

local function setter(key, after)
    return function(v)
        ns.Set(key, v)
        if after then after(v) end
    end
end

local function getter(key) return function() return ns.Get(key) end end

local function preview(v)
    if v == "chime" then
        PlaySoundFile(CHIME, "Master")
    elseif v == "game" then
        PlaySound(SOUNDKIT.TELL_MESSAGE, "Master")
    end
end

-------------------------------------------------------------------------------
--  Layout helpers
-------------------------------------------------------------------------------
local function section(text)
    local r = CreateFrame("Frame", nil, content)
    r.kind = "section"
    r.label = W.Text(r, "section", "muted")
    r.label:SetPoint("BOTTOMLEFT", 0, 4)
    r.label:SetText(text:upper())
    rows[#rows + 1] = r
    return r
end

local function row(label, desc, control)
    local r = CreateFrame("Frame", nil, content)
    r.kind = "row"
    r.label = W.Text(r, "label", "text")
    r.label:SetText(label)
    r.desc = desc and W.Text(r, "meta", "muted") or nil
    if r.desc then
        r.desc:SetText(desc)
        r.desc:SetWordWrap(true)
    end
    r.control = control
    control:SetParent(r)
    r.line = W.Hair(r, "BOTTOM", "hairSoft")
    rows[#rows + 1] = r
    return r
end

local function layout()
    if not content then return end
    local width = max(200, view:GetWidth() - 24)
    content:SetWidth(width)
    local y = 0
    for _, r in ipairs(rows) do
        if r:IsShown() then
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
            r:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -y)
            local h
            if r.kind == "section" then
                h = (y == 0) and 22 or 30
            else
                local cw = r.control:GetWidth()
                r.control:ClearAllPoints()
                r.control:SetPoint("RIGHT", r, "RIGHT", 0, 0)
                local textW = width - cw - 12
                r.label:ClearAllPoints()
                r.label:SetPoint("TOPLEFT", r, "TOPLEFT", 0, -7)
                r.label:SetWidth(textW)
                local lh = r.label:GetStringHeight()
                h = 7 + lh + 7
                if r.desc then
                    r.desc:ClearAllPoints()
                    r.desc:SetPoint("TOPLEFT", r.label, "BOTTOMLEFT", 0, -1)
                    r.desc:SetWidth(textW)
                    h = h + r.desc:GetStringHeight() + 1
                end
                h = max(h, r.control:GetHeight() + 12)
            end
            r:SetHeight(h)
            y = y + h
        end
    end
    content:SetHeight(y + 12)
    St.Scroll(0)
end

function St.Scroll(delta)
    if not scroll then return end
    local maxScroll = max(0, content:GetHeight() - scroll:GetHeight())
    local v = math.min(maxScroll, max(0, scroll:GetVerticalScroll() - delta * 30))
    scroll:SetVerticalScroll(v)
    if maxScroll > 0 then
        local vh = scroll:GetHeight()
        local h = max(16, vh * vh / content:GetHeight())
        thumb:ClearAllPoints()
        thumb:SetPoint("TOPRIGHT", view, "TOPRIGHT", -3, -(54 + (v / maxScroll) * (vh - h)))
        thumb:SetHeight(h)
        thumb:Show()
    else
        thumb:Hide()
    end
end

-------------------------------------------------------------------------------
--  Build
-------------------------------------------------------------------------------
function St.Build(v)
    view = v
    local head = CreateFrame("Frame", nil, v)
    head:SetPoint("TOPLEFT")
    head:SetPoint("TOPRIGHT")
    head:SetHeight(46)
    W.Hair(head, "BOTTOM")
    head:EnableMouse(true)
    head:RegisterForDrag("LeftButton")
    head:SetScript("OnDragStart", function() ns.UI.StartMoving() end)
    head:SetScript("OnDragStop", function() ns.UI.StopMoving() end)
    local title = W.Text(head, "title", "text")
    title:SetPoint("TOPLEFT", 12, -10)
    title:SetText(L["Settings"])
    local sub = W.Text(head, "meta", "muted")
    sub:SetPoint("TOPLEFT", 12, -28)
    sub:SetText(L["Changes apply right away"])
    local close = W.IconButton(head, "close", L["Back to conversations"], function() ns.UI.Show() end)
    close:SetPoint("RIGHT", -6, 0)

    scroll = CreateFrame("ScrollFrame", nil, v)
    scroll:SetPoint("TOPLEFT", 12, -50)
    scroll:SetPoint("BOTTOMRIGHT", -12, 4)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(_, d) St.Scroll(d) end)
    content = CreateFrame("Frame", nil, scroll)
    content:SetSize(300, 400)
    scroll:SetScrollChild(content)
    thumb = W.Fill(v, "scroll", "ARTWORK")
    thumb:SetWidth(2)
    thumb:Hide()

    local C = St.controls
    -- Only in WoW Forever's gamepad interface, where the game's own chat takes over.
    St.gamepad = row(L["Gamepad interface style"],
        L["While it is on, the game's own chat is used; Sotto keeps a copy of your whispers"],
        CreateFrame("Frame", nil, content))

    section(L["When a whisper arrives"])
    C.openOn = W.Segmented(content, {
        { value = "always", text = L["Always"] }, { value = "nocombat", text = L["Out of combat"] },
        { value = "never", text = L["Never"] },
    }, getter("openOn"), setter("openOn"))
    row(L["Open the window"], L["Otherwise a small notification pops up"], C.openOn)
    C.sound = W.Dropdown(content, {
        { value = "chime", text = L["Soft chime"] }, { value = "game", text = L["Game whisper"] },
        { value = "none", text = L["None"] },
    }, getter("sound"), setter("sound", preview))
    row(L["Sound"], nil, C.sound)
    C.hideInChat = W.Switch(content, getter("hideInChat"), setter("hideInChat"))
    row(L["Hide whispers from the chat window"], L["They still show there during boss fights"], C.hideInChat)

    section(L["When you whisper"])
    C.intercept = W.Switch(content, getter("intercept"), setter("intercept"))
    row(L["Use Sotto to whisper"],
        L["Your reply keys and Whisper in player menus open Sotto, and whispers you send from chat continue here"],
        C.intercept)

    section(L["Look"])
    C.accent = W.Segmented(content, {
        { value = "class", text = L["Class colour"] }, { value = "eui", text = L["EllesmereUI"] },
    }, getter("accent"), setter("accent"))
    row(L["Accent"], nil, C.accent)
    C.fontSize = W.Slider(content, 11, 16, 1, getter("fontSize"), setter("fontSize"))
    row(L["Text size"], nil, C.fontSize)
    C.fadeIdle = W.Switch(content, getter("fadeIdle"), setter("fadeIdle"))
    row(L["Fade when idle"], L["Fades while you are not using it"], C.fadeIdle)

    section(L["More"])
    C.keepDays = W.Dropdown(content, {
        { value = 0, text = L["Until logout"] }, { value = 7, text = L["7 days"] },
        { value = 30, text = L["30 days"] }, { value = 90, text = L["90 days"] },
    }, getter("keepDays"), setter("keepDays"))
    row(L["Remember conversations"], nil, C.keepDays)
    C.minimap = W.Switch(content, getter("minimap"), setter("minimap"))
    row(L["Minimap button"], nil, C.minimap)

    -- Only when the game opens whispers in new chat tabs.
    local inline = CreateFrame("Button", nil, content)
    inline.bg = W.Fill(inline, "accentWash")
    inline.bg:SetAllPoints()
    W.Border(inline, "accentBorder")
    inline.text = W.Text(inline, "small", "accent")
    inline.text:SetPoint("CENTER")
    inline.text:SetText(L["Use in-line"])
    inline:SetSize(ceil(inline.text:GetStringWidth()) + 18, 20)
    inline:SetScript("OnClick", function()
        SetCVar("whisperMode", "inline")
        St.Refresh()
    end)
    local wm = row(L["Blizzard opens whispers in new tabs"], L["Sotto works best with in-line whispers"], inline)
    wm.action = inline
    St.whisperMode = wm

    local foot = CreateFrame("Frame", nil, content)
    foot.kind = "section"
    foot.label = W.Text(foot, "hint", "faint")
    foot.label:SetPoint("BOTTOMLEFT", 0, 2)
    foot.label:SetText(string.format("Sotto %s · creazy231 · /sotto", ns.version))
    rows[#rows + 1] = foot

    v:SetScript("OnSizeChanged", layout)
    St.Refresh()
end

function St.Refresh()
    if not content then return end
    local C = St.controls
    for _, c in pairs(C) do if c.Refresh then c:Refresh() end end
    local gamepad = ns.Gamepad()
    St.gamepad:SetShown(gamepad)
    local mode = GetCVar and GetCVar("whisperMode")
    St.whisperMode:SetShown(mode ~= nil and mode ~= "inline" and not gamepad)
    layout()
end

ns.Listen("LOOKS_CHANGED", function() if content then layout() end end)
ns.Listen("GAMEPAD_CHANGED", function() St.Refresh() end)
