-------------------------------------------------------------------------------
--  Sotto: the compose box. Enter sends (long text is split by the engine) and
--  keeps the focus, like a messenger; Enter on an empty box or Esc goes back
--  to the game. Up/Down recall what you sent, Tab moves to the next
--  conversation. Each conversation keeps its own draft. Shift-clicked links
--  land here while the box has focus. In chat lockdown the draft waits.
--  One box per pane (the window's, and each separate window's):
--    ns.Compose.New(frame) -> compose   compose:SetConv(conv), :SaveDraft(), :SetText(text),
--                                       :Focus(), :HasFocus(), :UpdatePlaceholder()
--    ns.Compose.Focused()               the box that has the keyboard, or nil
--    ns.Compose.DropDraft(key)          a conversation's draft goes (it was closed)
--  Drafts and the sent lines Up/Down recall are shared by every box.
-------------------------------------------------------------------------------
local _, ns = ...
local Cp = {}
ns.Compose = Cp

local W, L = ns.W, ns.L

local drafts = {}
local history = {}
local MAX_HISTORY = 30
local boxes = {}

local Compose = {}
Compose.__index = Compose

local function borderColor(self)
    local name
    if ns.Engine.Locked() then
        name = "warnLine"
    elseif self.box:HasFocus() then
        name = "focus"
    else
        name = "euiBorder"
    end
    for _, t in ipairs(self.border) do W.SetFill(t, name) end
end

function Compose:UpdatePlaceholder()
    local text
    if ns.Engine.Locked() then
        text = L["Paused for the fight · your draft waits here"]
    elseif self.conv then
        text = string.format(L["Message %s…"], ns.Names.Short(ns.Contacts.Name(self.conv)))
    else
        text = ""
    end
    self.placeholder:SetText(text)
    self.placeholder:SetShown(self.box:GetText() == "")
    W.SetTextColor(self.placeholder, ns.Engine.Locked() and "warning" or "muted")
    borderColor(self)
end

function Compose:SaveDraft()
    if self.conv then drafts[self.conv.key] = self.box:GetText() end
end

function Compose:SetConv(c)
    self.conv = c
    self.histPos = nil
    self.box:SetText((c and drafts[c.key]) or "")
    self:UpdatePlaceholder()
end

function Compose:SetText(text)
    self.box:SetText(text or "")
    self.box:SetCursorPosition(#(text or ""))
end

function Compose:Focus()
    self.box:SetFocus()
end

function Compose:HasFocus()
    return self.box:HasFocus()
end

-- A short pulse of the border: Enter was pressed while sending is paused.
local function pulse(self)
    for _, t in ipairs(self.border) do W.SetFill(t, "warning") end
    C_Timer.After(0.35, function() borderColor(self) end)
end

local function send(self)
    local box = self.box
    local text = box:GetText()
    if not text:find("%S") then
        box:SetText("")
        box:ClearFocus()
        return
    end
    local conv = self.conv
    if not conv then return end
    if ns.Engine.Locked() or ns.InLockdown() then
        pulse(self)
        return
    end
    if ns.Engine.Send(conv, text) then
        history[#history + 1] = text
        if #history > MAX_HISTORY then table.remove(history, 1) end
        self.histPos = nil
        drafts[conv.key] = nil
        box:SetText("")
        -- Keep chatting in a city or an inn; anywhere else hand the keys back
        -- to the game (the reply key brings you straight back).
        if InCombatLockdown() or not (IsResting and IsResting()) then box:ClearFocus() end
    else
        pulse(self)
    end
end

function Cp.Focused()
    for _, c in ipairs(boxes) do
        if c.box:HasFocus() then return c end
    end
end

function Cp.DropDraft(key)
    if key then drafts[key] = nil end
end

-- Shift-clicked links come here while a box has focus and no Blizzard chat
-- box is open (Blizzard's box takes them first). One hook for every box.
local function onInsertLink(text)
    if ns.IsSecret(text) or type(text) ~= "string" then return end
    local c = Cp.Focused()
    if not c then return end
    local active = ChatFrameUtil and ChatFrameUtil.GetActiveWindow and ChatFrameUtil.GetActiveWindow()
    if active then return end
    c.box:Insert(text)
end

local hooked = false
local function hookLinks()
    if hooked then return end
    hooked = true
    if ChatFrameUtil and ChatFrameUtil.InsertLink then
        hooksecurefunc(ChatFrameUtil, "InsertLink", onInsertLink)
    elseif ChatEdit_InsertLink then
        hooksecurefunc("ChatEdit_InsertLink", onInsertLink)
    end
end

function Cp.New(f)
    local self = setmetatable({ frame = f }, Compose)
    W.Hair(f, "TOP")
    local field = CreateFrame("Frame", nil, f)
    field:SetPoint("TOPLEFT", 10, -7)
    field:SetPoint("BOTTOMRIGHT", -10, 9)
    field.bg = W.Fill(field, "inset")
    field.bg:SetAllPoints()
    self.border = W.Border(field, "euiBorder")
    self.field = field

    local box = CreateFrame("EditBox", nil, field)
    box:SetAllPoints()
    box:SetAutoFocus(false)
    box:SetMaxBytes(1024)
    box:SetTextInsets(8, 8, 0, 0)
    box:SetAltArrowKeyMode(false)
    W.ReleasedByWorld(box)
    W.Paint(box, function(b)
        b:SetFont(ns.Theme.Font("body"))
        b:SetTextColor(ns.Theme.Color("text"))
        b:SetShadowOffset(1, -1)
        b:SetShadowColor(0, 0, 0, 0.6)
    end)
    self.box = box

    self.placeholder = W.Text(field, "body", "muted")
    self.placeholder:SetPoint("LEFT", 8, 0)
    self.placeholder:SetPoint("RIGHT", -8, 0)

    box:SetScript("OnEnterPressed", function() send(self) end)
    box:SetScript("OnEscapePressed", function(b) b:ClearFocus() end)
    box:SetScript("OnTabPressed", function() if ns.UI.SelectNext then ns.UI.SelectNext(self.conv) end end)
    box:SetScript("OnArrowPressed", function(_, key)
        if #history == 0 then return end
        if key == "UP" then
            self.histPos = math.max(1, (self.histPos or (#history + 1)) - 1)
            self:SetText(history[self.histPos])
        elseif key == "DOWN" and self.histPos then
            self.histPos = self.histPos + 1
            if self.histPos > #history then
                self.histPos = nil
                self:SetText("")
            else
                self:SetText(history[self.histPos])
            end
        end
    end)
    box:SetScript("OnTextChanged", function(b)
        self.placeholder:SetShown(b:GetText() == "")
        if self.conv then drafts[self.conv.key] = b:GetText() end
    end)
    box:SetScript("OnEditFocusGained", function()
        borderColor(self)
        ns.Fire("COMPOSE_FOCUS", true, self)
    end)
    box:SetScript("OnEditFocusLost", function()
        borderColor(self)
        ns.Fire("COMPOSE_FOCUS", false, self)
    end)
    field:EnableMouse(true)
    field:SetScript("OnMouseDown", function() box:SetFocus() end)

    hookLinks()
    boxes[#boxes + 1] = self
    self:UpdatePlaceholder()
    return self
end

ns.Listen("LOCKDOWN_CHANGED", function()
    for _, c in ipairs(boxes) do c:UpdatePlaceholder() end
end)
ns.Listen("LOOKS_CHANGED", function()
    for _, c in ipairs(boxes) do borderColor(c) end
end)
