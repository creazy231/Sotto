-------------------------------------------------------------------------------
--  Sotto: the window. Rail + chat (approved mockup, 410 x 306 by default):
--  the rail on the left; on the right one of three views: a conversation
--  (header, notices, log, compose box), the settings, or the empty view.
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

local RAIL_W, HEAD_H = 46, 46
local IDLE_AFTER, IDLE_ALPHA, FADE_TIME = 4, 0.42, 0.3

local active        -- the conversation in the chat view
local view = "empty"
local wimState      -- nil | "on" | "off" (WIM disabled, reload pending)

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
--  Chat view
-------------------------------------------------------------------------------
local chat = CreateFrame("Frame", nil, main)
chat:SetAllPoints()

local head = CreateFrame("Frame", nil, chat)
head:SetPoint("TOPLEFT")
head:SetPoint("TOPRIGHT")
head:SetHeight(HEAD_H)
head:EnableMouse(true)
head:RegisterForDrag("LeftButton")
head:SetScript("OnDragStart", UI.StartMoving)
head:SetScript("OnDragStop", UI.StopMoving)
head.sky = head:CreateTexture(nil, "BACKGROUND", nil, 1)
head.sky:SetAllPoints()
W.Paint(head.sky, function(t)
    local r, g, b = ns.Theme.Color("sky")
    t:SetColorTexture(1, 1, 1, 1)
    t:SetGradient("VERTICAL", CreateColor(r, g, b, 0), CreateColor(r, g, b, 0.55))
end)
W.Hair(head, "BOTTOM")

head.dot = head:CreateTexture(nil, "ARTWORK")
head.dot:SetTexture(W.MEDIA .. "circle")
head.dot:SetSize(6, 6)
head.dot:SetPoint("TOPLEFT", 12, -15)
head.name = W.Text(head, "name", "text")
head.name:SetPoint("TOPLEFT", 24, -10)
head.meta = W.Text(head, "meta", "muted")
head.meta:SetPoint("TOPLEFT", 12, -28)

head.close = W.IconButton(head, "close", L["Close"], function() UI.Hide() end)
head.close:SetPoint("RIGHT", -6, 0)
head.vsep = W.Fill(head, "hair", "ARTWORK")
head.vsep:SetSize(1, 14)
head.vsep:SetPoint("RIGHT", head.close, "LEFT", -4, 0)
W.Paint(head.vsep, function(t) t:SetWidth(W.Pixel(head)) end)
head.more = W.IconButton(head, "more", L["More"], function(self) UI.MoreMenu(self) end)
head.more:SetPoint("RIGHT", head.vsep, "LEFT", -4, 0)
head.invite = W.IconButton(head, "invite", L["Invite to group"], function() UI.Invite() end)
head.invite:SetPoint("RIGHT", head.more, "LEFT", -1, 0)
head.name:SetPoint("RIGHT", head.invite, "LEFT", -8, 0)
head.meta:SetPoint("RIGHT", head.invite, "LEFT", -8, 0)
UI.header = head

-- WIM notice
local notice = CreateFrame("Frame", nil, chat)
notice:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 10, -8)
notice:SetPoint("TOPRIGHT", head, "BOTTOMRIGHT", -10, -8)
notice:SetHeight(28)
notice.bg = W.Fill(notice, "accentWash")
notice.bg:SetAllPoints()
notice.bar = W.Fill(notice, "accent", "ARTWORK")
notice.bar:SetPoint("TOPLEFT")
notice.bar:SetPoint("BOTTOMLEFT")
notice.bar:SetWidth(2)
notice.text = W.Text(notice, "small", "text")
notice.text:SetPoint("LEFT", 10, 0)
notice.action = CreateFrame("Button", nil, notice)
notice.action:SetPoint("RIGHT", -8, 0)
notice.action.text = W.Text(notice.action, "small", "accent")
notice.action.text:SetPoint("CENTER")
notice.text:SetPoint("RIGHT", notice.action, "LEFT", -8, 0)
notice:Hide()
UI.notice = notice

-- Chat lockdown banner
local banner = CreateFrame("Frame", nil, chat)
banner:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 10, -8)
banner:SetPoint("TOPRIGHT", head, "BOTTOMRIGHT", -10, -8)
banner:SetHeight(34)
banner.bg = W.Fill(banner, "warnBg")
banner.bg:SetAllPoints()
banner.bar = W.Fill(banner, "warning", "ARTWORK")
banner.bar:SetPoint("TOPLEFT")
banner.bar:SetPoint("BOTTOMLEFT")
banner.bar:SetWidth(2)
banner.icon = W.Icon(banner, "warn", 13, "warning")
banner.icon:SetPoint("TOPLEFT", 10, -7)
banner.text = W.Text(banner, "meta", "warningText")
banner.text:SetPoint("TOPLEFT", 30, -6)
banner.text:SetPoint("RIGHT", -8, 0)
banner.text:SetWordWrap(true)
banner.text:SetText(L["Boss fight: whispers can't be read by addons right now. They show in your chat and land here when it ends."])
banner:Hide()
UI.banner = banner

local logFrame = CreateFrame("Frame", nil, chat)
local composeFrame = CreateFrame("Frame", nil, chat)
composeFrame:SetPoint("BOTTOMLEFT")
composeFrame:SetPoint("BOTTOMRIGHT")
composeFrame:SetHeight(42)
logFrame:SetPoint("BOTTOMLEFT", composeFrame, "TOPLEFT")
logFrame:SetPoint("BOTTOMRIGHT", composeFrame, "TOPRIGHT")

function UI.Layout()
    local top = head
    if notice:IsShown() then top = notice end
    if banner:IsShown() then
        banner:ClearAllPoints()
        banner:SetPoint("TOPLEFT", top, "BOTTOMLEFT", top == head and 10 or 0, -8)
        banner:SetPoint("TOPRIGHT", top, "BOTTOMRIGHT", top == head and -10 or 0, -8)
        banner:SetHeight(max(30, banner.text:GetStringHeight() + 12))
        top = banner
    end
    logFrame:ClearAllPoints()
    logFrame:SetPoint("TOPLEFT", top, "BOTTOMLEFT", top == head and 0 or -10, top == head and 0 or -2)
    logFrame:SetPoint("TOPRIGHT", top, "BOTTOMRIGHT", top == head and 0 or 10, top == head and 0 or -2)
    logFrame:SetPoint("BOTTOMLEFT", composeFrame, "TOPLEFT")
    logFrame:SetPoint("BOTTOMRIGHT", composeFrame, "TOPRIGHT")
    ns.Log.Render()
end

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
--  New conversation: a name field over the header. Sotto never opens
--  Blizzard's chat box (see Core/Intercept.lua).
-------------------------------------------------------------------------------
local prompt = CreateFrame("Frame", nil, main)
prompt:SetPoint("TOPLEFT")
prompt:SetPoint("TOPRIGHT")
prompt:SetHeight(HEAD_H)
prompt:SetFrameLevel(main:GetFrameLevel() + 30)
prompt:EnableMouse(true)
prompt.bg = W.Fill(prompt, "panel")
prompt.bg:SetAllPoints()
W.Hair(prompt, "BOTTOM", "accentLine")
prompt.label = W.Text(prompt, "section", "muted")
prompt.label:SetPoint("TOPLEFT", 12, -6)
prompt.label:SetText(L["Whisper to"]:upper())
prompt.close = W.IconButton(prompt, "close", L["Cancel"], function() UI.ClosePrompt() end)
prompt.close:SetPoint("RIGHT", -6, 0)
local promptField = CreateFrame("Frame", nil, prompt)
promptField:SetPoint("TOPLEFT", 10, -19)
promptField:SetPoint("BOTTOMRIGHT", prompt.close, "BOTTOMLEFT", -6, 1)
promptField.bg = W.Fill(promptField, "inset")
promptField.bg:SetAllPoints()
W.Border(promptField, "focus")
prompt.edit = CreateFrame("EditBox", nil, promptField)
prompt.edit:SetAllPoints()
prompt.edit:SetAutoFocus(false)
prompt.edit:SetTextInsets(6, 6, 0, 0)
W.Paint(prompt.edit, function(e)
    e:SetFont(ns.Theme.Font("body"))
    e:SetTextColor(ns.Theme.Color("text"))
end)
prompt.hint = W.Text(promptField, "body", "muted")
prompt.hint:SetPoint("LEFT", 6, 0)
prompt.hint:SetText(L["Name"])
prompt:Hide()
UI.prompt = prompt

-- The name as the game spells it: a known conversation, a friend, a guild
-- mate, else each word capitalised (the server's spelling replaces it with
-- the first message either way).
local function properName(input)
    local key = ns.Names.Key(input)
    if not key then return nil end
    local known = ns.Store.Get(key)
    if known then return known.name end
    if C_FriendList and C_FriendList.GetNumFriends then
        for i = 1, C_FriendList.GetNumFriends() or 0 do
            local f = C_FriendList.GetFriendInfoByIndex(i)
            local n = type(f) == "table" and f.name
            if not ns.IsSecret(n) and type(n) == "string" and ns.Names.Key(n) == key then return ns.Names.Display(n) end
        end
    end
    if IsInGuild and IsInGuild() then
        for i = 1, GetNumGuildMembers() or 0 do
            local n = GetGuildRosterInfo(i)
            if not ns.IsSecret(n) and type(n) == "string" and ns.Names.Key(n) == key then return ns.Names.Display(n) end
        end
    end
    return (ns.Names.Display(input):gsub("(%a)([%w']*)", function(a, b) return a:upper() .. b:lower() end))
end

function UI.NewConversation()
    if not win:IsShown() then UI.Show() end
    if view == "settings" then UI.Show() end
    prompt.edit:SetText("")
    prompt.hint:Show()
    prompt:Show()
    prompt.edit:SetFocus()
end

function UI.ClosePrompt()
    prompt.edit:ClearFocus()
    prompt:Hide()
end

prompt.edit:SetScript("OnTextChanged", function(self) prompt.hint:SetShown(self:GetText() == "") end)
prompt.edit:SetScript("OnEscapePressed", function() UI.ClosePrompt() end)
prompt.edit:SetScript("OnEnterPressed", function(self)
    local name = properName((self:GetText():gsub("^%s+", ""):gsub("%s+$", "")))
    UI.ClosePrompt()
    local conv = name and ns.Store.Ensure("w", name)
    if conv then UI.Open(conv, { focus = true }) end
end)

ns.Rail.Build(rail)
ns.Log.Build(logFrame)
ns.Compose.Build(composeFrame)
ns.Settings.Build(settings)

-------------------------------------------------------------------------------
--  Views
-------------------------------------------------------------------------------
function UI.View() return view end
function UI.IsShown() return win:IsShown() end
function UI.Active() return view == "chat" and active or nil end
function UI.Typing(conv) return ns.Compose.HasFocus() and UI.Active() == conv end

function UI.ShowView(name)
    view = name
    chat:SetShown(name == "chat")
    settings:SetShown(name == "settings")
    empty:SetShown(name == "empty")
    if name == "settings" then ns.Settings.Refresh() end
    ns.Rail.Refresh()
end

function UI.UpdateHeader()
    local c = active
    if not c then return end
    head.name:SetText(ns.Contacts.Name(c))
    local r, g, b = ns.Contacts.Color(c)
    W.SetTextColor(head.name, { r, g, b })
    if c.online == nil then
        head.dot:Hide()
        head.name:SetPoint("TOPLEFT", 12, -10)
    else
        head.dot:SetVertexColor(ns.Theme.Color(c.online and "success" or "offline"))
        head.dot:Show()
        head.name:SetPoint("TOPLEFT", 24, -10)
    end
    local sep = " |c" .. ns.Theme.Hex("faint") .. "·|r "
    head.meta:SetText(table.concat(ns.Contacts.Meta(c), sep))
    local canInvite = c.kind == "w" or (c.kind == "bn" and c.char ~= nil)
    head.invite:SetEnabled(canInvite)
    head.invite:SetAlpha(canInvite and 1 or 0.35)
end

local function firstUnreadIndex(conv)
    local n = conv.unread or 0
    if n <= 0 then return nil end
    local count = 0
    for i = #conv.msgs, 1, -1 do
        if conv.msgs[i].d == "i" then
            count = count + 1
            if count == n then return i end
        end
    end
    return 1
end

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
    ns.Compose.SaveDraft()
    local newIndex = firstUnreadIndex(conv)
    active = conv
    ns.Store.MarkRead(conv)
    UI.ShowView("chat")
    UI.UpdateHeader()
    ns.Log.SetConv(conv, newIndex)
    ns.Compose.SetConv(conv)
    ns.Contacts.Refresh(conv)
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
    if opts.text then ns.Compose.SetText(opts.text) end
    if opts.focus then ns.Compose.Focus() end
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
    ns.Compose.SaveDraft()
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
        local focused = ns.Compose.HasFocus()
        UI.Select(c)
        if focused then ns.Compose.Focus() end
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
local function transcript(conv)
    local out = {}
    for _, m in ipairs(conv.msgs) do
        local who = m.d == "o" and L["You"] or (m.d == "s" and "*" or ns.Contacts.Name(conv))
        out[#out + 1] = string.format("[%s %s] %s: %s", ns.Format.DayKey(m.t), ns.Format.Time(m.t), who,
            ns.Format.Plain(m.m or ""))
    end
    return table.concat(out, "\n")
end

function UI.Invite()
    local c = active
    if not c then return end
    local name = c.kind == "bn" and c.char or c.name
    if not name then return end
    local invite = (C_PartyInfo and C_PartyInfo.InviteUnit) or InviteUnit
    if invite then invite(name) end
end

function UI.MoreMenu(anchor)
    local c = active
    if not c then return end
    local items = {}
    if c.kind == "w" then
        items[#items + 1] = { text = L["Add friend"], func = function() C_FriendList.AddFriend(c.name) end }
        items[#items + 1] = { text = L["Ignore"], func = function() C_FriendList.AddIgnore(c.name) end }
    end
    items[#items + 1] = { text = L["Copy name"], func = function()
        ns.CopyBox.Show(L["Copy name"], c.kind == "bn" and (c.tag or ns.Contacts.Name(c)) or c.name)
    end }
    items[#items + 1] = { text = L["Copy conversation"], func = function()
        ns.CopyBox.Show(L["Copy conversation"], transcript(c))
    end }
    items[#items + 1] = { text = L["Clear history"], func = function() ns.Store.Clear(c) end }
    items[#items + 1] = { text = L["Close conversation"], color = "danger", func = function() ns.Store.Close(c) end }
    W.Menu(anchor, items, 170, "RIGHT")
end

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
    ns.Log.Refresh()
end

win:SetScript("OnSizeChanged", function()
    ns.Log.Refresh()
    if view == "settings" then ns.Settings.Refresh() end
    ns.Rail.Refresh()
end)

-------------------------------------------------------------------------------
--  Idle fade (a 0.25 s check while shown; the tween runs only while moving)
-------------------------------------------------------------------------------
local idleSince, targetAlpha = 0, 1
local fadeTicker

local function tween(self, elapsed)
    local cur = self:GetAlpha()
    local d = targetAlpha - cur
    local s = elapsed / FADE_TIME
    if math.abs(d) <= s then
        self:SetAlpha(targetAlpha)
        self:SetScript("OnUpdate", nil)
    else
        self:SetAlpha(cur + (d > 0 and s or -s))
    end
end

local function fadeTo(a)
    if targetAlpha == a and win:GetAlpha() == a then return end
    targetAlpha = a
    win:SetScript("OnUpdate", tween)
end

local function awake()
    if not ns.Get("fadeIdle") then return true end
    if win:IsMouseOver() or ns.Compose.HasFocus() then return true end
    local menu = W.CurrentMenu()
    if menu and menu:IsShown() then return true end
    return false
end

local function checkIdle()
    if not win:IsShown() then return end
    if awake() then
        idleSince = GetTime()
        fadeTo(1)
    elseif GetTime() - idleSince >= IDLE_AFTER then
        fadeTo(IDLE_ALPHA)
    end
end

function UI.Wake()
    idleSince = GetTime()
    fadeTo(1)
end

win:SetScript("OnShow", function()
    idleSince = GetTime()
    win:SetAlpha(1)
    targetAlpha = 1
    if not fadeTicker then fadeTicker = C_Timer.NewTicker(0.25, checkIdle) end
    ns.Toast.HideAll()
    ns.Rail.Refresh()
    ns.Contacts.ScheduleRefresh()
end)

win:SetScript("OnHide", function()
    if fadeTicker then fadeTicker:Cancel(); fadeTicker = nil end
    win:SetScript("OnUpdate", nil)
    ns.Compose.SaveDraft()
    if ns.Compose.HasFocus() then ns.Compose.box:ClearFocus() end
    W.CloseMenu()
end)

-------------------------------------------------------------------------------
--  WIM
-------------------------------------------------------------------------------
local function updateNotice()
    if wimState == "on" then
        notice.text:SetText(L["WIM is running too, so whispers arrive twice."])
        notice.action.text:SetText(L["Turn off WIM"])
    elseif wimState == "off" then
        notice.text:SetText(L["WIM turns off after a reload."])
        notice.action.text:SetText(L["Reload now"])
    end
    notice.action:SetSize(floor(notice.action.text:GetStringWidth()) + 12, 20)
    notice:SetShown(wimState ~= nil)
    UI.Layout()
end

notice.action:SetScript("OnClick", function()
    if wimState == "on" then
        local disable = (C_AddOns and C_AddOns.DisableAddOn) or DisableAddOn
        if disable then
            disable("WIM")
            disable("EllesmereSkin_WIM")
        end
        wimState = "off"
        updateNotice()
    elseif wimState == "off" then
        ReloadUI()
    end
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
    if conv == active and view == "chat" then ns.Log.OnMessage(conv) end
end)

ns.Listen("CONV_UPDATED", function(conv)
    if active and not active.open then
        -- The keyboard must not carry on into another conversation.
        if ns.Compose.HasFocus() then ns.Compose.box:ClearFocus() end
        local list = ns.Store.List()
        if win:IsShown() and list[1] then
            UI.Select(list[1])
        else
            active = nil
            if view == "chat" then UI.ShowView("empty") end
        end
    elseif conv == active and view == "chat" then
        ns.Log.Refresh()
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
    elseif view ~= "settings" and active ~= conv and not ns.Compose.HasFocus() then
        UI.Select(conv)
    end
end)

ns.Listen("LOCKDOWN_CHANGED", function(locked)
    banner:SetShown(locked)
    UI.Layout()
end)

ns.Listen("COMPOSE_FOCUS", function() UI.Wake() end)

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
    local loaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
    if loaded and loaded("WIM") then
        wimState = "on"
        updateNotice()
    end
    UI.Layout()
end)
