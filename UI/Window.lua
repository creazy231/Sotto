-------------------------------------------------------------------------------
--  Sotto: the window. Rail + chat (approved mockup, 410 x 306 by default):
--  the rail on the left; on the right one of three views: a conversation
--  (the chat column, UI/Pane.lua), the settings, or the empty view.
--  It moves by its header or the mark, resizes from the corner, remembers
--  where it was, takes the Scale setting (its bottom-left corner stays put),
--  and fades while idle. With "Keep windows open" (on by default) Esc and
--  loading screens leave it open and a login brings back what was on screen;
--  off, Esc closes it. In WoW Forever's gamepad interface (ns.Gamepad) no
--  whisper opens it or a notification, and the switch to that interface
--  closes both (Keep windows open brings them back after it); by hand it
--  still opens.
--  With "Separate windows" on, every conversation opens in its own window
--  (UI/Windows.lua) and this window is the dock: the rail alone ("dock"
--  view), as tall as its conversations, growing up from its saved corner;
--  its gear still opens the settings at the full saved size.
-------------------------------------------------------------------------------
local _, ns = ...
local UI = {}
ns.UI = UI

local W, L = ns.W, ns.L
local floor, max, min = math.floor, math.max, math.min

local RAIL_W = 46
local DOCK_TOP, DOCK_BOTTOM, DOCK_ROW = 45, 62, 40 -- the rail's mark, its "+" and gear, a badge

local active        -- the conversation in the chat view
local view = "empty"
local docked = false -- the window has the dock's size
local carried       -- shown here when separate windows were turned on in the settings: opens on their close

local function separate() return ns.Get("separate") == true end
UI.Separate = separate

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
W.Escapable("SottoWindow") -- Esc closes it only with Keep windows open off

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
UI.grip = grip

-------------------------------------------------------------------------------
--  New conversation: the name field over the header
-------------------------------------------------------------------------------
function UI.NewConversation()
    if separate() then return ns.Windows.NewConversation() end
    if not win:IsShown() then UI.Show() end
    if view == "settings" then UI.Show() end
    pane:ShowPrompt()
end

function UI.ClosePrompt()
    pane:ClosePrompt()
    if separate() then ns.Windows.CancelPrompts() end
end

ns.Rail.Build(rail)
ns.Settings.Build(settings)

-------------------------------------------------------------------------------
--  Views
-------------------------------------------------------------------------------
function UI.View() return view end

-- Anything of Sotto's on screen: this window or a separate one.
function UI.IsShown() return win:IsShown() or ns.Windows.AnyShown() end

-- The conversation being looked at: the chat view's, or with separate windows
-- the one brought up last.
function UI.Active()
    if separate() then return ns.Windows.Front() end
    return view == "chat" and active or nil
end

-- This conversation is on screen (its whispers count as read).
function UI.Sees(conv)
    if not conv then return false end
    if separate() then return ns.Windows.Sees(conv) end
    return win:IsShown() and view == "chat" and active == conv
end

-- The conversations on screen.
function UI.OnScreen()
    if separate() then return ns.Windows.OnScreen() end
    return (win:IsShown() and view == "chat" and active) and { active } or {}
end

function UI.Typing(conv)
    if separate() then return ns.Windows.Typing(conv) end
    return UI.compose:HasFocus() and UI.Active() == conv
end

function UI.ShowView(name)
    view = name
    chat:SetShown(name == "chat")
    settings:SetShown(name == "settings")
    empty:SetShown(name == "empty")
    main:SetShown(name ~= "dock")
    grip:SetShown(name ~= "dock")
    if docked ~= (name == "dock") then
        docked = name == "dock"
        UI.ApplyGeometry()
    end
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
-- With separate windows: the dock.
function UI.Show()
    if not win:IsShown() then win:Show() end
    if separate() then
        UI.ShowView("dock")
        local conv = carried
        carried = nil
        if conv and conv.open then ns.Windows.Open(conv) end
        UI.Wake()
        return
    end
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
    if separate() then
        ns.Windows.Open(conv, opts)
        return
    end
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

-- Tab in a compose box: the next conversation (with separate windows the
-- next open window after `from`'s).
function UI.SelectNext(from)
    if separate() then return ns.Windows.FocusNext(from) end
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
-- The dock: the rail's mark, a row per conversation, "+" and the gear; at
-- most the window's height (the rail scrolls beyond).
local function dockHeight(g)
    return min(g.h or 306, DOCK_TOP + DOCK_BOTTOM + DOCK_ROW * #ns.Store.List())
end

function UI.ApplyGeometry()
    local g = ns.DB and ns.DB.window
    if not g then return end
    local s = W.Scale()
    if docked then
        win:SetSize(RAIL_W, dockHeight(g))
    else
        win:SetSize(g.w or 410, g.h or 306)
    end
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
    if not docked then -- the dock's size is not the window's
        g.w, g.h = floor(win:GetWidth() + 0.5), floor(win:GetHeight() + 0.5)
    end
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
-- The player at the window reads the conversation it shows.
local fader = W.Fader(win, function() return UI.compose:HasFocus() or pane.prompt.edit:HasFocus() end, function()
    if view == "chat" and active and (active.unread or 0) > 0 then ns.Store.MarkRead(active) end
end)

function UI.Wake() fader:Wake() end

-- On screen with the player at it lately: a whisper is read. One into a faded
-- window counts unread until the player looks (the mouse over it, its keyboard).
function UI.Reads(conv)
    if separate() then return ns.Windows.Reads(conv) end
    return UI.Sees(conv) and not fader:Idle()
end

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
    pane:ClosePrompt() -- a hidden name field must not keep the keyboard
    carried = nil
    W.CloseMenu()
end)

-------------------------------------------------------------------------------
--  Events
-------------------------------------------------------------------------------
ns.Listen("INCOMING", function(conv, msg, wantOpen)
    if separate() then
        -- A window opening (or coming up) over the box the player types in
        -- would hide what they type: a card instead, as in combat.
        if ns.Windows.Sees(conv) then
            ns.Windows.Flash(conv)
        elseif ns.Gamepad() then
            return
        elseif wantOpen and not ns.Windows.TypingElsewhere(conv) then
            ns.Windows.Open(conv, { whisper = true })
        else
            ns.Toast.Show(conv, msg)
        end
        return
    end
    if win:IsShown() then
        fader:Flash()
        if view == "empty" then
            -- Taken up while nobody is at the window, it stays unread.
            local away, n = fader:Idle(), conv.unread or 0
            UI.Select(conv)
            if away and n > 0 then ns.Store.MarkUnread(conv, n) end
        end
    elseif ns.Gamepad() then
        return -- the game's own chat has it, made for the controller
    elseif wantOpen then
        UI.Open(conv)
    else
        ns.Toast.Show(conv, msg)
    end
end)

ns.Listen("MESSAGE_ADDED", function(conv)
    if separate() then return ns.Windows.OnMessage(conv) end
    if conv == active and view == "chat" then UI.log:OnMessage(conv) end
end)

-- The dock is as tall as its conversations.
local function redock()
    if docked then UI.ApplyGeometry() end
end

ns.Listen("CONV_ADDED", function()
    redock()
    ns.Rail.Refresh()
end)

ns.Listen("CONV_UPDATED", function(conv)
    if separate() then
        ns.Windows.OnUpdate(conv)
        redock()
        ns.Rail.Refresh()
        return
    end
    if active and not active.open then
        -- The keyboard must not carry on into another conversation; the
        -- settings stay open (they show the next one when they close).
        if UI.compose:HasFocus() then UI.compose.box:ClearFocus() end
        local list = ns.Store.List()
        if win:IsShown() and view == "chat" and list[1] then
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
    ns.Windows.OnContact(conv)
    ns.Rail.Refresh()
end)

ns.Listen("UNREAD_CHANGED", function(conv)
    -- Whispers came in unseen (a faded window): the New line above the first.
    if conv and conv == active and view == "chat" and win:IsShown() and not separate()
        and (conv.unread or 0) > 0 then
        pane:MarkNew()
    end
    ns.Rail.Refresh()
end)

ns.Listen("CONTACTS_REFRESHED", function()
    UI.UpdateHeader()
    ns.Windows.OnContact(nil)
    ns.Rail.Refresh()
end)

-- A whisper sent from the chat box continues in Sotto.
ns.Listen("OUTGOING", function(conv, opens)
    if not opens then return end
    if separate() then
        if not ns.Windows.Sees(conv) then ns.Windows.Open(conv) end
        return
    end
    if not win:IsShown() then
        UI.Open(conv)
    elseif view ~= "settings" and active ~= conv and not UI.compose:HasFocus() then
        UI.Select(conv)
    end
end)

ns.Listen("COMPOSE_FOCUS", function(_, compose)
    if compose == UI.compose then UI.Wake() end
end)

-------------------------------------------------------------------------------
--  Keep windows open: what is on screen at logout comes back at the next login
--  (the window on its conversation; with separate windows the dock and every
--  window in its place, the front one in front), and what the gamepad interface
--  hid comes back after it. Closed or minimised by hand stays so, and so does a
--  conversation closed meanwhile.
-------------------------------------------------------------------------------
local stash    -- what was on screen when the gamepad interface took over
local restored -- the login brought it back (later loading screens bring nothing)

-- { window = shown, conv = the window's conversation, wins = { { conv, x, y } } }
local function snapshot()
    return { window = win:IsShown(), conv = (not separate()) and active or nil, wins = ns.Windows.Shown() }
end

-- Into the way the setting says now (it may have changed while the gamepad
-- interface held them): the window's conversation gets its own window, or the
-- window shows the separate window that was in front.
local function restore(s)
    if not s then return end
    local wins = s.wins or {}
    if separate() then
        if s.window and not win:IsShown() then UI.Show() end
        if #wins == 0 and s.conv then wins = { { conv = s.conv } } end
        local kept = {}
        for _, it in ipairs(wins) do
            local conv = it.conv
            if conv and conv.open then
                kept[#kept + 1] = { conv, conv.unread or 0 }
                ns.Windows.Open(conv, { at = (it.x and it.y) and { it.x, it.y } or nil })
            end
        end
        -- Opening reads a window; one that came back covered keeps its unread.
        for _, k in ipairs(kept) do
            if k[2] > 0 and not ns.Windows.Sees(k[1]) then ns.Store.MarkUnread(k[1], k[2]) end
        end
        return
    end
    local conv = s.conv
    for i = #wins, 1, -1 do
        if not (conv and conv.open) then conv = wins[i].conv end
    end
    if (s.window or #wins > 0) and not win:IsShown() then
        if conv and conv.open then UI.Open(conv) else UI.Show() end
    end
end

-- Saved: the window's state in SottoDB.window (shown, conv), each separate
-- window's in its conversation (conv.up = { n = its place in the stack, x, y }),
-- so another character's conversations keep theirs.
local function save(s)
    local g = ns.DB and ns.DB.window
    if not g then return end
    g.shown = s.window and true or nil
    g.conv = s.conv and s.conv.key or nil
    for _, conv in ipairs(ns.Store.List()) do conv.up = nil end
    for i, it in ipairs(s.wins or {}) do
        if it.conv then it.conv.up = { n = i, x = it.x, y = it.y } end
    end
end

local function saved()
    local g = ns.DB and ns.DB.window
    if not g then return nil end
    local wins = {}
    for _, conv in ipairs(ns.Store.List()) do
        local up = conv.up
        if type(up) == "table" then
            wins[#wins + 1] = { conv = conv, x = tonumber(up.x), y = tonumber(up.y), n = tonumber(up.n) or 0 }
        end
    end
    table.sort(wins, function(a, b) return a.n < b.n end)
    local conv = type(g.conv) == "string" and ns.Store.Get(g.conv) or nil
    return { window = g.shown == true, conv = conv, wins = wins }
end

ns.On("PLAYER_LOGOUT", function() save(stash or snapshot()) end)

-- The session's first loading screen, after the login pruned old history.
ns.On("PLAYER_ENTERING_WORLD", function()
    if restored then return end
    restored = true
    if not ns.Get("keepOpen") then return end
    local s = saved()
    if ns.Gamepad() then stash = s else restore(s) end
end)

-- Into the gamepad interface: the controller cannot reach the window or the
-- notifications, and the game's own chat takes the whispers from now on. Out
-- of it, Keep windows open shows again what it hid.
ns.Listen("GAMEPAD_CHANGED", function(on)
    if on == true then
        stash = stash or snapshot() -- a stash from the login is what to bring back
        ns.Toast.HideAll()
        UI.Hide()
        ns.Windows.HideAll()
        return
    end
    local s = stash
    stash = nil
    if ns.Get("keepOpen") then restore(s) end
end)

-- Separate windows on: the conversation shown here moves into its own window
-- (at the same place, the chat column's) and the window docks. Off: the
-- separate windows go and the window shows the one brought up last.
local function switchMode(on)
    if on then
        local conv = (win:IsShown() and view == "chat") and active or nil
        local typing = conv and UI.compose:HasFocus()
        UI.compose:SaveDraft()
        if typing then UI.compose.box:ClearFocus() end
        UI.compose:SetConv(nil) -- its draft now belongs to the separate window
        UI.log:Clear()
        pane:ClosePrompt()
        -- Turned on in the settings: the conversation shown before them gets
        -- its own window when they close.
        carried = (win:IsShown() and view == "settings" and active and active.open) and active or nil
        if win:IsShown() and view ~= "settings" then UI.ShowView("dock") end
        if conv then ns.Windows.Open(conv, { focus = typing }) end
    else
        carried = nil
        local front = ns.Windows.Front()
        local shown = ns.Windows.AnyShown()
        ns.Windows.ReleaseAll()
        if front then active = front end
        if win:IsShown() and view ~= "settings" then
            UI.Show()
        elseif shown and not win:IsShown() then
            UI.Show() -- what was on screen stays on screen, in the window
        end
    end
end

ns.Listen("SETTING_CHANGED", function(key, value)
    if key == "fadeIdle" then UI.Wake() end
    if key == "separate" then switchMode(value == true) end
end)

ns.Listen("DB_READY", function() UI.ApplyGeometry() end)
ns.Listen("SCALE_CHANGED", function() UI.ApplyGeometry() end)

ns.On("PLAYER_LOGIN", function()
    UI.ApplyGeometry()
    UI.Layout()
end)
