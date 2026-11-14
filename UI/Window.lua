-------------------------------------------------------------------------------
--  Sotto: the window. Rail + chat (approved mockup, 410 x 306 by default):
--  the rail on the left; on the right one of three views: a conversation
--  (the chat column, UI/Pane.lua), the settings, or the empty view.
--  It moves by its header or the mark, resizes from the corner, closes with
--  Esc, remembers where it was, takes the Scale setting (its bottom-left
--  corner stays put), and fades while idle. In WoW Forever's gamepad
--  interface (ns.Gamepad) no whisper opens it or a notification, and the
--  switch to that interface closes both; by hand it still opens.
-------------------------------------------------------------------------------
local _, ns = ...
local UI = {}
ns.UI = UI

local W, L = ns.W, ns.L
local floor, max = math.floor, math.max

local RAIL_W = 46

local active        -- the conversation in the chat view
local view = "empty"

-------------------------------------------------------------------------------
--  Frame
-------------------------------------------------------------------------------
local win = W.Scaled(CreateFrame("Frame", "SottoWindow", UIParent))
UI.win = win
win:SetSize(410, 306)
win:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 22, 328)
win:SetFrameStrata("MEDIUM")
win:SetToplevel(true)
win:SetClampedToScreen(true)
win:SetMovable(true)
win:SetResizable(true)
if win.SetResizeBounds then win:SetResizeBounds(320, 200, 900, 720) end
if win.SetDontSavePosition then win:SetDontSavePosition(true) end
win:EnableMouse(true)
win:Hide()
tinsert(UISpecialFrames, "SottoWindow")

win.bg = W.Fill(win, "bg", "BACKGROUND", -7)
win.bg:SetAllPoints()
W.Shadow(win, 16, 0.55)
W.Outline(win, "edge")
W.Border(win, "hair", "OVERLAY")

local rail = CreateFrame("Frame", nil, win)
rail:SetPoint("TOPLEFT")
rail:SetPoint("BOTTOMLEFT")
rail:SetWidth(RAIL_W)
rail.bg = W.Fill(rail, "sidebar")
rail.bg:SetAllPoints()
W.Hair(rail, "RIGHT")

local main = CreateFrame("Frame", nil, win)
main:SetPoint("TOPLEFT", rail, "TOPRIGHT")
main:SetPoint("BOTTOMRIGHT")

function UI.StartMoving() win:StartMoving() end
function UI.StopMoving()
    win:StopMovingOrSizing()
    UI.SavePosition()
end

-------------------------------------------------------------------------------
--  Chat view: the conversation's column
-------------------------------------------------------------------------------
local chat = CreateFrame("Frame", nil, main)
chat:SetAllPoints()

local pane = ns.Pane.New(chat, {
    onClose = function() UI.Hide() end,
    promptParent = main,
    onPick = function(_, name)
        local conv = name and ns.Store.Ensure("w", name)
        if conv then UI.Open(conv, { focus = true }) end
    end,
    move = { start = UI.StartMoving, stop = UI.StopMoving },
})
UI.pane = pane
UI.header, UI.notice, UI.banner, UI.prompt = pane.head, pane.notice, pane.banner, pane.prompt
UI.log, UI.compose = pane.log, pane.compose

function UI.Layout() pane:Layout() end

-------------------------------------------------------------------------------
--  Settings and empty views
-------------------------------------------------------------------------------
local settings = CreateFrame("Frame", nil, main)
settings:SetAllPoints()
settings:Hide()

local empty = CreateFrame("Frame", nil, main)
empty:SetAllPoints()
empty:Hide()
do
    empty.haze = empty:CreateTexture(nil, "BACKGROUND", nil, 1)
    empty.haze:SetTexture(W.MEDIA .. "haze")
    empty.haze:SetSize(240, 160)
    empty.haze:SetPoint("CENTER", 0, 18)
    W.Paint(empty.haze, function(t) t:SetVertexColor(ns.Theme.Color("accentWash")) end)
    empty.mark = W.Icon(empty, W.MEDIA .. "mark", 30, "accent")
    empty.mark:SetPoint("CENTER", 0, 46)
    empty.title = W.Text(empty, "big", "text")
    empty.title:SetPoint("CENTER", 0, 16)
    empty.title:SetText(L["No whispers yet"])
    empty.desc = W.Text(empty, "small", "muted")
    empty.desc:SetPoint("TOP", empty.title, "BOTTOM", 0, -6)
    empty.desc:SetJustifyH("CENTER")
    empty.desc:SetWordWrap(true)
    empty.desc:SetWidth(280)
    empty.desc:SetText(L["Whisper someone, or wait for a message.\nEvery conversation gets a spot in the rail."])
    empty.chips = {}
    local labels = { L["/w Name"], L["Reply key"], L["Whisper in menus"] }
    local total = 0
    for i, text in ipairs(labels) do
        local chip = W.Pill(empty, 18, "chip")
        chip.text = W.Text(chip, "hint", "dim")
        chip.text:SetPoint("CENTER")
        chip.text:SetText(text)
        chip:SetWidth(floor(chip.text:GetStringWidth()) + 18)
        total = total + chip:GetWidth() + (i > 1 and 6 or 0)
        empty.chips[i] = chip
    end
    local x = -total / 2
    for i, chip in ipairs(empty.chips) do
        chip:SetPoint("TOPLEFT", empty, "CENTER", x, -46)
        x = x + chip:GetWidth() + 6
    end
    empty.close = W.IconButton(empty, "close", L["Close"], function() UI.Hide() end)
    empty.close:SetPoint("TOPRIGHT", -6, -6)
    empty:EnableMouse(true)
    empty:RegisterForDrag("LeftButton")
    empty:SetScript("OnDragStart", UI.StartMoving)
    empty:SetScript("OnDragStop", UI.StopMoving)
end

-- Resize grip
local grip = CreateFrame("Button", nil, win)
grip:SetSize(12, 12)
grip:SetPoint("BOTTOMRIGHT", -2, 2)
grip:SetFrameLevel(win:GetFrameLevel() + 20)
grip.tex = grip:CreateTexture(nil, "OVERLAY")
grip.tex:SetTexture(W.MEDIA .. "grip")
grip.tex:SetAllPoints()
grip.tex:SetAlpha(0.35)
grip:SetScript("OnEnter", function(self) self.tex:SetAlpha(0.7) end)
grip:SetScript("OnLeave", function(self) self.tex:SetAlpha(0.35) end)
grip:SetScript("OnMouseDown", function() win:StartSizing("BOTTOMRIGHT") end)
grip:SetScript("OnMouseUp", function()
    win:StopMovingOrSizing()
    UI.SavePosition()
end)

-------------------------------------------------------------------------------
--  New conversation: the name field over the header
-------------------------------------------------------------------------------
function UI.NewConversation()
    if not win:IsShown() then UI.Show() end
    if view == "settings" then UI.Show() end
    pane:ShowPrompt()
end

function UI.ClosePrompt()
    pane:ClosePrompt()
end

ns.Rail.Build(rail)
ns.Settings.Build(settings)

-------------------------------------------------------------------------------
--  Views
-------------------------------------------------------------------------------
function UI.View() return view end
function UI.IsShown() return win:IsShown() end
function UI.Active() return view == "chat" and active or nil end
function UI.Typing(conv) return UI.compose:HasFocus() and UI.Active() == conv end

function UI.ShowView(name)
    view = name
    chat:SetShown(name == "chat")
    settings:SetShown(name == "settings")
    empty:SetShown(name == "empty")
    if name == "settings" then ns.Settings.Refresh() end
    ns.Rail.Refresh()
end

function UI.UpdateHeader() pane:UpdateHeader() end

function UI.Select(conv)
    if not conv then return end
    if not conv.open then
        conv.open = true -- starting a closed conversation again brings it back
        ns.Fire("CONV_UPDATED", conv)
    end
    if view == "chat" and active == conv then
        ns.Store.MarkRead(conv)
        return
    end
    active = conv
    UI.ShowView("chat")
    pane:SetConv(conv)
end

-- Show the window on the last conversation, the newest one, or the empty view.
function UI.Show()
    if not win:IsShown() then win:Show() end
    local list = ns.Store.List()
    local target = (active and active.open) and active or list[1]
    if target then
        view = "none" -- select again: marks it read and places the New line
        UI.Select(target)
    else
        active = nil
        UI.ShowView("empty")
    end
    UI.Wake()
end

function UI.Open(conv, opts)
    if type(opts) ~= "table" then opts = {} end
    if not conv then return UI.Show() end
    if not win:IsShown() then win:Show() end
    UI.Select(conv)
    if opts.text then UI.compose:SetText(opts.text) end
    if opts.focus then UI.compose:Focus() end
    ns.Toast.HideFor(conv)
    UI.Wake()
end

function UI.Toggle()
    if win:IsShown() then UI.Hide() else UI.Show() end
end

function UI.Hide()
    win:Hide()
end

function UI.ShowSettings()
    if not win:IsShown() then win:Show() end
    UI.compose:SaveDraft()
    UI.ShowView("settings")
    UI.Wake()
end

local function step(dir)
    local list = ns.Store.List()
    if #list == 0 then return end
    local idx = 0
    for i, c in ipairs(list) do if c == active then idx = i end end
    for k = 1, #list do
        local c = list[(idx + k * dir - 1) % #list + 1]
        if c ~= active then return c end
    end
end

function UI.SelectNext()
    local c = step(1)
    if c then
        local focused = UI.compose:HasFocus()
        UI.Select(c)
        if focused then UI.compose:Focus() end
    end
end

function UI.SelectNextUnread()
    for _, c in ipairs(ns.Store.List()) do
        if (c.unread or 0) > 0 then return UI.Open(c, { focus = true }) end
    end
    UI.Show()
end

-------------------------------------------------------------------------------
--  Header actions
-------------------------------------------------------------------------------
function UI.Invite() pane:Invite() end
function UI.MoreMenu(anchor) pane:MoreMenu(anchor) end

-------------------------------------------------------------------------------
--  Position
-------------------------------------------------------------------------------
-- The bottom-left corner is saved in UIParent's units, the size in the
-- window's own. The anchor's offsets are in the window's units, which grow
-- with its scale, so they are divided by it: the corner stays where it was
-- saved, whatever the scale.
function UI.ApplyGeometry()
    local g = ns.DB and ns.DB.window
    if not g then return end
    local s = W.Scale()
    win:SetSize(g.w or 410, g.h or 306)
    win:ClearAllPoints()
    win:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", (g.x or 22) / s, (g.y or 328) / s)
end

function UI.SavePosition()
    local g = ns.DB and ns.DB.window
    if not g then return end
    local left, bottom = win:GetLeft(), win:GetBottom()
    if not left or not bottom then return end
    local s = W.Scale() -- GetLeft and GetBottom are in the window's units
    g.point = "BOTTOMLEFT"
    g.x, g.y = floor(left * s + 0.5), floor(bottom * s + 0.5)
    g.w, g.h = floor(win:GetWidth() + 0.5), floor(win:GetHeight() + 0.5)
    win:ClearAllPoints()
    win:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", g.x / s, g.y / s)
end

function UI.ResetGeometry()
    if not ns.DB then return end
    for k, v in pairs(ns.DEFAULTS.window) do ns.DB.window[k] = v end
    UI.ApplyGeometry()
    UI.log:Refresh()
end

win:SetScript("OnSizeChanged", function()
    UI.log:Refresh()
    if view == "settings" then ns.Settings.Refresh() end
    ns.Rail.Refresh()
end)

-------------------------------------------------------------------------------
--  Idle fade
-------------------------------------------------------------------------------
local fader = W.Fader(win, function() return UI.compose:HasFocus() end)

function UI.Wake() fader:Wake() end

win:SetScript("OnShow", function()
    fader:Start()
    ns.Toast.HideAll()
    ns.Rail.Refresh()
    ns.Contacts.ScheduleRefresh()
end)

win:SetScript("OnHide", function()
    fader:Stop()
    UI.compose:SaveDraft()
    if UI.compose:HasFocus() then UI.compose.box:ClearFocus() end
    W.CloseMenu()
end)

-------------------------------------------------------------------------------
--  Events
-------------------------------------------------------------------------------
ns.Listen("INCOMING", function(conv, msg, wantOpen)
    if win:IsShown() then
        UI.Wake()
        if view == "empty" then UI.Select(conv) end
    elseif ns.Gamepad() then
        return -- the game's own chat has it, made for the controller
    elseif wantOpen then
        UI.Open(conv)
    else
        ns.Toast.Show(conv, msg)
    end
end)

ns.Listen("MESSAGE_ADDED", function(conv)
    if conv == active and view == "chat" then UI.log:OnMessage(conv) end
end)

ns.Listen("CONV_UPDATED", function(conv)
    if active and not active.open then
        -- The keyboard must not carry on into another conversation.
        if UI.compose:HasFocus() then UI.compose.box:ClearFocus() end
        local list = ns.Store.List()
        if win:IsShown() and list[1] then
            UI.Select(list[1])
        else
            active = nil
            if view == "chat" then UI.ShowView("empty") end
        end
    elseif conv == active and view == "chat" then
        UI.log:Refresh()
        UI.UpdateHeader()
    end
    ns.Rail.Refresh()
end)

ns.Listen("CONTACT_UPDATED", function(conv)
    if conv == active then UI.UpdateHeader() end
    ns.Rail.Refresh()
end)

ns.Listen("UNREAD_CHANGED", function() ns.Rail.Refresh() end)

ns.Listen("CONTACTS_REFRESHED", function()
    UI.UpdateHeader()
    ns.Rail.Refresh()
end)

-- A whisper sent from the chat box continues in Sotto.
ns.Listen("OUTGOING", function(conv, opens)
    if not opens then return end
    if not win:IsShown() then
        UI.Open(conv)
    elseif view ~= "settings" and active ~= conv and not UI.compose:HasFocus() then
        UI.Select(conv)
    end
end)

ns.Listen("COMPOSE_FOCUS", function(_, compose)
    if compose == UI.compose then UI.Wake() end
end)

-- Into the gamepad interface: the controller cannot reach the window or the
-- notifications, and the game's own chat takes the whispers from now on.
ns.Listen("GAMEPAD_CHANGED", function(on)
    if on ~= true then return end
    ns.Toast.HideAll()
    UI.Hide()
end)

ns.Listen("SETTING_CHANGED", function(key)
    if key == "fadeIdle" then UI.Wake() end
end)

ns.Listen("DB_READY", function() UI.ApplyGeometry() end)
ns.Listen("SCALE_CHANGED", function() UI.ApplyGeometry() end)

ns.On("PLAYER_LOGIN", function()
    UI.ApplyGeometry()
    UI.Layout()
end)
