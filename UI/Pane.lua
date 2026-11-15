-------------------------------------------------------------------------------
--  Sotto: a conversation's column (the approved chat column): the header
--  (online dot, name in class colour, "level · race class · zone", invite,
--  "…" menu and its last button), the WIM notice, the chat lockdown banner,
--  the log, the compose box, and the "Whisper to" field that covers the
--  header for a new conversation. The window has one; each separate window
--  has its own, with the rail's class tile at the left of its header.
--    ns.Pane.New(frame, opts) -> pane
--      opts.icon, opts.tip, opts.onClose(pane, mouseButton)   the header's last button
--      opts.tile                         the conversation's class tile in the header
--      opts.promptParent                 what the name field spans (the pane's frame)
--      opts.onPick(pane, name)           Enter in the name field (nil: nothing usable)
--      opts.onCancel(pane)               Esc or its cancel button (closes the field)
--      opts.closeItem(pane) -> item      the "…" menu's last entry
--      opts.move = { start, stop }       dragging the header
--    pane:SetConv(conv)   shows a conversation: the New line at its first unread
--                         message, marks it read, refreshes the contact
--    pane:UpdateHeader(), :Layout(), :ShowPrompt(), :ClosePrompt(), :MoreMenu(anchor),
--    :Invite(); pane.conv, .head, .notice, .banner, .prompt, .log, .compose
--    ns.Pane.ProperName(input)   a typed name as the game spells it
-------------------------------------------------------------------------------
local _, ns = ...
local P = {}
ns.Pane = P

local W, L = ns.W, ns.L
local floor, max = math.floor, math.max

local HEAD_H, TILE = 46, 28

local panes = {}
P.all = panes
local wimState -- nil | "on" | "off" (WIM disabled, reload pending)

local Pane = {}
Pane.__index = Pane

-------------------------------------------------------------------------------
--  Names
-------------------------------------------------------------------------------
-- The name as the game spells it: a known conversation, a friend, a guild
-- mate, else each word capitalised (the server's spelling replaces it with
-- the first message either way).
function P.ProperName(input)
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

-------------------------------------------------------------------------------
--  Header
-------------------------------------------------------------------------------
local function buildHead(self, frame, opts)
    local head = CreateFrame("Frame", nil, frame)
    head:SetPoint("TOPLEFT")
    head:SetPoint("TOPRIGHT")
    head:SetHeight(HEAD_H)
    head:EnableMouse(true)
    head:RegisterForDrag("LeftButton")
    if opts.move then
        head:SetScript("OnDragStart", opts.move.start)
        head:SetScript("OnDragStop", opts.move.stop)
    end
    head.sky = head:CreateTexture(nil, "BACKGROUND", nil, 1)
    head.sky:SetAllPoints()
    W.Paint(head.sky, function(t)
        local r, g, b = ns.Theme.Color("sky")
        t:SetColorTexture(1, 1, 1, 1)
        t:SetGradient("VERTICAL", CreateColor(r, g, b, 0), CreateColor(r, g, b, 0.55))
    end)
    W.Hair(head, "BOTTOM")

    -- Where the text starts: after the tile, if the pane has one.
    head.x = 12
    if opts.tile then
        head.tile = ns.Rail.NewTile(head, TILE)
        head.tile:SetPoint("TOPLEFT", 10, -(HEAD_H - TILE) / 2)
        head.x = 10 + TILE + 10
    end
    head.dot = head:CreateTexture(nil, "ARTWORK")
    head.dot:SetTexture(W.MEDIA .. "circle")
    head.dot:SetSize(6, 6)
    head.dot:SetPoint("TOPLEFT", head.x, -15)
    head.name = W.Text(head, "name", "text")
    head.name:SetPoint("TOPLEFT", head.x + 12, -10)
    head.meta = W.Text(head, "meta", "muted")
    head.meta:SetPoint("TOPLEFT", head.x, -28)

    head.close = W.IconButton(head, opts.icon or "close", opts.tip or L["Close"], function(b, mouse)
        if opts.onClose then opts.onClose(self, mouse, b) end
    end)
    head.close:SetPoint("RIGHT", -6, 0)
    head.vsep = W.Fill(head, "hair", "ARTWORK")
    head.vsep:SetSize(1, 14)
    head.vsep:SetPoint("RIGHT", head.close, "LEFT", -4, 0)
    W.Paint(head.vsep, function(t) t:SetWidth(W.Pixel(head)) end)
    head.more = W.IconButton(head, "more", L["More"], function(b) self:MoreMenu(b) end)
    head.more:SetPoint("RIGHT", head.vsep, "LEFT", -4, 0)
    head.invite = W.IconButton(head, "invite", L["Invite to group"], function() self:Invite() end)
    head.invite:SetPoint("RIGHT", head.more, "LEFT", -1, 0)
    head.name:SetPoint("RIGHT", head.invite, "LEFT", -8, 0)
    head.meta:SetPoint("RIGHT", head.invite, "LEFT", -8, 0)
    return head
end

function Pane:UpdateHeader()
    local c = self.conv
    if not c then return end
    local head = self.head
    head.name:SetText(ns.Contacts.Name(c))
    local r, g, b = ns.Contacts.Color(c)
    W.SetTextColor(head.name, { r, g, b })
    if c.online == nil then
        head.dot:Hide()
        head.name:SetPoint("TOPLEFT", head.x, -10)
    else
        head.dot:SetVertexColor(ns.Theme.Color(c.online and "success" or "offline"))
        head.dot:Show()
        head.name:SetPoint("TOPLEFT", head.x + 12, -10)
    end
    local sep = " |c" .. ns.Theme.Hex("faint") .. "·|r "
    head.meta:SetText(table.concat(ns.Contacts.Meta(c), sep))
    local canInvite = c.kind == "w" or (c.kind == "bn" and c.char ~= nil)
    head.invite:SetEnabled(canInvite)
    head.invite:SetAlpha(canInvite and 1 or 0.35)
    if head.tile then ns.Rail.PaintTile(head.tile, c) end
end

-------------------------------------------------------------------------------
--  Notices: WIM (every pane says it) and the chat lockdown banner
-------------------------------------------------------------------------------
local function buildNotice(head, frame)
    local notice = CreateFrame("Frame", nil, frame)
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
    return notice
end

local function buildBanner(head, frame)
    local banner = CreateFrame("Frame", nil, frame)
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
    return banner
end

local function updateNotice(self)
    local notice = self.notice
    if wimState == "on" then
        notice.text:SetText(L["WIM is running too, so whispers arrive twice."])
        notice.action.text:SetText(L["Turn off WIM"])
    elseif wimState == "off" then
        notice.text:SetText(L["WIM turns off after a reload."])
        notice.action.text:SetText(L["Reload now"])
    end
    notice.action:SetSize(floor(notice.action.text:GetStringWidth()) + 12, 20)
    notice:SetShown(wimState ~= nil)
    self:Layout()
end

local function wimAction()
    if wimState == "on" then
        local disable = (C_AddOns and C_AddOns.DisableAddOn) or DisableAddOn
        if disable then
            disable("WIM")
            disable("EllesmereSkin_WIM")
        end
        wimState = "off"
        for _, p in ipairs(panes) do updateNotice(p) end
    elseif wimState == "off" then
        ReloadUI()
    end
end

function Pane:Layout()
    local head, notice, banner, logFrame = self.head, self.notice, self.banner, self.logFrame
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
    logFrame:SetPoint("BOTTOMLEFT", self.composeFrame, "TOPLEFT")
    logFrame:SetPoint("BOTTOMRIGHT", self.composeFrame, "TOPRIGHT")
    self.log:Render()
end

-------------------------------------------------------------------------------
--  "Whisper to": a name field over the header. Sotto never opens Blizzard's
--  chat box (see Core/Intercept.lua).
-------------------------------------------------------------------------------
local function buildPrompt(self, parent, opts)
    local prompt = CreateFrame("Frame", nil, parent)
    prompt:SetPoint("TOPLEFT")
    prompt:SetPoint("TOPRIGHT")
    prompt:SetHeight(HEAD_H)
    prompt:SetFrameLevel(parent:GetFrameLevel() + 30)
    prompt:EnableMouse(true)
    -- It covers the header, so it moves the window as the header does.
    prompt:RegisterForDrag("LeftButton")
    if opts.move then
        prompt:SetScript("OnDragStart", opts.move.start)
        prompt:SetScript("OnDragStop", opts.move.stop)
    end
    prompt.bg = W.Fill(prompt, "panel")
    prompt.bg:SetAllPoints()
    W.Hair(prompt, "BOTTOM", "accentLine")
    prompt.label = W.Text(prompt, "section", "muted")
    prompt.label:SetPoint("TOPLEFT", 12, -6)
    prompt.label:SetText(L["Whisper to"]:upper())
    local function cancel()
        if opts.onCancel then opts.onCancel(self) else self:ClosePrompt() end
    end
    prompt.close = W.IconButton(prompt, "close", L["Cancel"], cancel)
    prompt.close:SetPoint("RIGHT", -6, 0)
    local field = CreateFrame("Frame", nil, prompt)
    field:SetPoint("TOPLEFT", 10, -19)
    field:SetPoint("BOTTOMRIGHT", prompt.close, "BOTTOMLEFT", -6, 1)
    field.bg = W.Fill(field, "inset")
    field.bg:SetAllPoints()
    W.Border(field, "focus")
    prompt.edit = CreateFrame("EditBox", nil, field)
    prompt.edit:SetAllPoints()
    prompt.edit:SetAutoFocus(false)
    prompt.edit:SetTextInsets(6, 6, 0, 0)
    W.Paint(prompt.edit, function(e)
        e:SetFont(ns.Theme.Font("body"))
        e:SetTextColor(ns.Theme.Color("text"))
    end)
    prompt.hint = W.Text(field, "body", "muted")
    prompt.hint:SetPoint("LEFT", 6, 0)
    prompt.hint:SetText(L["Name"])
    prompt:Hide()

    prompt.edit:SetScript("OnTextChanged", function(e) prompt.hint:SetShown(e:GetText() == "") end)
    prompt.edit:SetScript("OnEscapePressed", cancel)
    prompt.edit:SetScript("OnEnterPressed", function(e)
        local name = P.ProperName((e:GetText():gsub("^%s+", ""):gsub("%s+$", "")))
        self:ClosePrompt()
        if opts.onPick then opts.onPick(self, name) end
    end)
    return prompt
end

function Pane:ShowPrompt()
    local prompt = self.prompt
    prompt.edit:SetText("")
    prompt.hint:Show()
    prompt:Show()
    prompt.edit:SetFocus()
end

function Pane:ClosePrompt()
    self.prompt.edit:ClearFocus()
    self.prompt:Hide()
end

-------------------------------------------------------------------------------
--  Conversation
-------------------------------------------------------------------------------
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

function Pane:SetConv(conv)
    self.compose:SaveDraft()
    local newIndex = firstUnreadIndex(conv)
    self.conv = conv
    ns.Store.MarkRead(conv)
    self:UpdateHeader()
    self.log:SetConv(conv, newIndex)
    self.compose:SetConv(conv)
    ns.Contacts.Refresh(conv)
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

function Pane:Invite()
    local c = self.conv
    if not c then return end
    local name = c.kind == "bn" and c.char or c.name
    if not name then return end
    local invite = (C_PartyInfo and C_PartyInfo.InviteUnit) or InviteUnit
    if invite then invite(name) end
end

function Pane:MoreMenu(anchor)
    local c = self.conv
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
    items[#items + 1] = self.opts.closeItem and self.opts.closeItem(self)
        or { text = L["Close conversation"], color = "danger", func = function() ns.Store.Close(c) end }
    W.Menu(anchor, items, 170, "RIGHT")
end

-------------------------------------------------------------------------------
--  Build
-------------------------------------------------------------------------------
function P.New(frame, opts)
    opts = opts or {}
    local self = setmetatable({ frame = frame, opts = opts }, Pane)
    self.head = buildHead(self, frame, opts)
    self.notice = buildNotice(self.head, frame)
    self.notice.action:SetScript("OnClick", wimAction)
    self.banner = buildBanner(self.head, frame)

    local logFrame = CreateFrame("Frame", nil, frame)
    local composeFrame = CreateFrame("Frame", nil, frame)
    composeFrame:SetPoint("BOTTOMLEFT")
    composeFrame:SetPoint("BOTTOMRIGHT")
    composeFrame:SetHeight(42)
    logFrame:SetPoint("BOTTOMLEFT", composeFrame, "TOPLEFT")
    logFrame:SetPoint("BOTTOMRIGHT", composeFrame, "TOPRIGHT")
    self.logFrame, self.composeFrame = logFrame, composeFrame
    self.prompt = buildPrompt(self, opts.promptParent or frame, opts)
    self.log = ns.Log.New(logFrame)
    self.compose = ns.Compose.New(composeFrame)

    panes[#panes + 1] = self
    -- A pane made later (a separate window) starts with what the others show.
    if ns.Engine.Locked() then self.banner:Show() end
    if wimState ~= nil then updateNotice(self) end
    return self
end

ns.Listen("LOCKDOWN_CHANGED", function(locked)
    for _, p in ipairs(panes) do
        p.banner:SetShown(locked)
        p:Layout()
    end
end)

ns.On("PLAYER_LOGIN", function()
    local loaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
    if loaded and loaded("WIM") then
        wimState = "on"
        for _, p in ipairs(panes) do updateNotice(p) end
    end
end)
