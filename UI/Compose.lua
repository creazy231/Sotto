-------------------------------------------------------------------------------
--  Sotto: the compose box. Enter sends (long text is split by the engine) and
--  keeps the focus, like a messenger; Enter on an empty box or Esc goes back
--  to the game. Up/Down recall what you sent, Tab moves to the next
--  conversation. Each conversation keeps its own draft. Shift-clicked links
--  land here while the box has focus. In chat lockdown the draft waits.
-------------------------------------------------------------------------------
local _, ns = ...
local Cp = {}
ns.Compose = Cp

local W, L = ns.W, ns.L

local box, field, border
local conv
local drafts = {}
local history, histPos = {}, nil
local MAX_HISTORY = 30

local function borderColor()
    local name
    if ns.Engine.Locked() then
        name = "warnLine"
    elseif box and box:HasFocus() then
        name = "focus"
    else
        name = "euiBorder"
    end
    for _, t in ipairs(border) do W.SetFill(t, name) end
end

function Cp.UpdatePlaceholder()
    if not box then return end
    local text
    if ns.Engine.Locked() then
        text = L["Paused for the fight · your draft waits here"]
    elseif conv then
        text = string.format(L["Message %s…"], ns.Names.Short(ns.Contacts.Name(conv)))
    else
        text = ""
    end
    Cp.placeholder:SetText(text)
    Cp.placeholder:SetShown(box:GetText() == "")
    W.SetTextColor(Cp.placeholder, ns.Engine.Locked() and "warning" or "muted")
    borderColor()
end

function Cp.SaveDraft()
    if conv and box then drafts[conv.key] = box:GetText() end
end

function Cp.SetConv(c)
    conv = c
    histPos = nil
    box:SetText((c and drafts[c.key]) or "")
    Cp.UpdatePlaceholder()
end

function Cp.SetText(text)
    box:SetText(text or "")
    box:SetCursorPosition(#(text or ""))
end

function Cp.Focus()
    if box then box:SetFocus() end
end

function Cp.HasFocus()
    return box ~= nil and box:HasFocus()
end

-- A short pulse of the border: Enter was pressed while sending is paused.
local function pulse()
    if not border then return end
    for _, t in ipairs(border) do W.SetFill(t, "warning") end
    C_Timer.After(0.35, borderColor)
end

local function send(self)
    local text = self:GetText()
    if not text:find("%S") then
        self:SetText("")
        self:ClearFocus()
        return
    end
    if not conv then return end
    if ns.Engine.Locked() or ns.InLockdown() then
        pulse()
        return
    end
    if ns.Engine.Send(conv, text) then
        history[#history + 1] = text
        if #history > MAX_HISTORY then table.remove(history, 1) end
        histPos = nil
        drafts[conv.key] = nil
        self:SetText("")
        -- Keep chatting in a city or an inn; anywhere else hand the keys back
        -- to the game (the reply key brings you straight back).
        if InCombatLockdown() or not (IsResting and IsResting()) then self:ClearFocus() end
    else
        pulse()
    end
end

function Cp.Build(f)
    Cp.frame = f
    W.Hair(f, "TOP")
    field = CreateFrame("Frame", nil, f)
    field:SetPoint("TOPLEFT", 10, -7)
    field:SetPoint("BOTTOMRIGHT", -10, 9)
    field.bg = W.Fill(field, "inset")
    field.bg:SetAllPoints()
    border = W.Border(field, "euiBorder")

    box = CreateFrame("EditBox", nil, field)
    box:SetAllPoints()
    box:SetAutoFocus(false)
    box:SetMaxBytes(1024)
    box:SetTextInsets(8, 8, 0, 0)
    box:SetAltArrowKeyMode(false)
    W.Paint(box, function(b)
        b:SetFont(ns.Theme.Font("body"))
        b:SetTextColor(ns.Theme.Color("text"))
        b:SetShadowOffset(1, -1)
        b:SetShadowColor(0, 0, 0, 0.6)
    end)
    Cp.box = box

    Cp.placeholder = W.Text(field, "body", "muted")
    Cp.placeholder:SetPoint("LEFT", 8, 0)
    Cp.placeholder:SetPoint("RIGHT", -8, 0)

    box:SetScript("OnEnterPressed", send)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    box:SetScript("OnTabPressed", function() if ns.UI.SelectNext then ns.UI.SelectNext() end end)
    box:SetScript("OnArrowPressed", function(self, key)
        if #history == 0 then return end
        if key == "UP" then
            histPos = math.max(1, (histPos or (#history + 1)) - 1)
            Cp.SetText(history[histPos])
        elseif key == "DOWN" and histPos then
            histPos = histPos + 1
            if histPos > #history then
                histPos = nil
                Cp.SetText("")
            else
                Cp.SetText(history[histPos])
            end
        end
    end)
    box:SetScript("OnTextChanged", function(self)
        Cp.placeholder:SetShown(self:GetText() == "")
        if conv then drafts[conv.key] = self:GetText() end
    end)
    box:SetScript("OnEditFocusGained", function()
        borderColor()
        ns.Fire("COMPOSE_FOCUS", true)
    end)
    box:SetScript("OnEditFocusLost", function()
        borderColor()
        ns.Fire("COMPOSE_FOCUS", false)
    end)
    field:EnableMouse(true)
    field:SetScript("OnMouseDown", function() box:SetFocus() end)

    -- Shift-clicked links come here while the box has focus and no Blizzard
    -- chat box is open (Blizzard's box takes them first).
    local function onInsertLink(text)
        if not box:HasFocus() or ns.IsSecret(text) or type(text) ~= "string" then return end
        local active = ChatFrameUtil and ChatFrameUtil.GetActiveWindow and ChatFrameUtil.GetActiveWindow()
        if active then return end
        box:Insert(text)
    end
    if ChatFrameUtil and ChatFrameUtil.InsertLink then
        hooksecurefunc(ChatFrameUtil, "InsertLink", onInsertLink)
    elseif ChatEdit_InsertLink then
        hooksecurefunc("ChatEdit_InsertLink", onInsertLink)
    end
    Cp.UpdatePlaceholder()
end

ns.Listen("LOCKDOWN_CHANGED", function() Cp.UpdatePlaceholder() end)
ns.Listen("LOOKS_CHANGED", function() if box then borderColor() end end)
