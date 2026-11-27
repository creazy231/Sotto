-------------------------------------------------------------------------------
--  Sotto: the message log. Grouped runs (name and time once per run of
--  messages from one side within 5 minutes), day separators, a "New" divider
--  before the first unread message, system lines. Only the rows in view are
--  drawn; heights are measured once per message, width and text size.
--  The newest message sits at the bottom; scrolling back keeps your place
--  when new messages arrive and offers a "New messages" pill instead.
--  One log per pane (the window's, and each separate window's):
--    ns.Log.New(frame) -> log    log:SetConv(conv, firstUnread), log:Refresh(),
--                                log:Render(), log:OnMessage(conv), log:Scroll(d),
--                                log:ScrollToBottom(), log:Clear(),
--                                log:SetNew(i) (the New line above message i)
-------------------------------------------------------------------------------
local _, ns = ...
local Lg = {}
ns.Log = Lg

local W, L = ns.W, ns.L
local floor, max, min = math.floor, math.max, math.min

local GROUP_GAP = 5 * 60
local PAD_X, PAD_TOP, PAD_BOTTOM = 12, 6, 8
local H_DAY, H_NEW, H_HEAD = 22, 20, 24

-- Measured heights, shared by every log (a message is measured per width and size).
local heights = setmetatable({}, { __mode = "k" })
local logs = {}

local Log = {}
Log.__index = Log

-------------------------------------------------------------------------------
--  Items
-------------------------------------------------------------------------------
local function build(self)
    local items = {}
    self.items = items
    local conv, newMsg = self.conv, self.newMsg
    if not conv then return end
    local prevDay, prev
    local now = time()
    for i, msg in ipairs(conv.msgs) do
        local day = ns.Format.DayKey(msg.t)
        if day ~= prevDay then
            items[#items + 1] = { kind = "day", text = ns.Format.Day(msg.t, now) }
            prevDay, prev = day, nil
        end
        if newMsg and msg == newMsg then
            items[#items + 1] = { kind = "new" }
            prev = nil
        end
        if msg.d == "s" then
            items[#items + 1] = { kind = "sys", msg = msg }
            prev = nil
        else
            if not prev or prev.d ~= msg.d or msg.t - prev.t > GROUP_GAP then
                items[#items + 1] = { kind = "head", msg = msg }
            end
            items[#items + 1] = { kind = "line", msg = msg }
            prev = msg
        end
    end
end

local function lineText(msg)
    return ns.Format.Linkify(msg.m or "")
end

local function measureItem(self, it, width)
    if it.kind == "day" then return H_DAY end
    if it.kind == "new" then return H_NEW end
    if it.kind == "head" then return H_HEAD end
    local fs = it.kind == "sys" and self.measureSmall or self.measure
    local w = it.kind == "sys" and (width - 18) or width
    local _, size = ns.Theme.Font(it.kind == "sys" and "small" or "body")
    local c = heights[it.msg]
    if c and c.w == w and c.size == size then return c.h end
    fs:SetWidth(w)
    fs:SetText(it.kind == "sys" and (it.msg.m or "") or lineText(it.msg))
    local h = fs:GetStringHeight() + (it.kind == "sys" and 9 or 3)
    heights[it.msg] = { w = w, size = size, h = h }
    return h
end

local function layout(self)
    local width = self.content:GetWidth()
    local y = 0
    for _, it in ipairs(self.items) do
        it.top = y
        it.h = measureItem(self, it, width)
        y = y + it.h
    end
    self.total = y
end

-------------------------------------------------------------------------------
--  Rows
-------------------------------------------------------------------------------
local LINK_TIPS = { item = true, spell = true, quest = true, achievement = true, currency = true, enchant = true,
    talent = true, battlepet = true }

local function onLinkClick(self, link, text, button)
    if ns.IsSecret(link) or type(link) ~= "string" then return end
    local url = link:match("^sotto:url:(.+)$")
    if url then
        ns.CopyBox.Show(L["Copy link"], url)
        return
    end
    -- A plain left click on a name in a whisper does nothing (WIM behaviour).
    if link:find("^player:") and button == "LeftButton" and not IsModifiedClick() then return end
    SetItemRef(link, text, button, self)
end

local function onLinkEnter(self, link)
    if ns.IsSecret(link) or type(link) ~= "string" then return end
    local kind = link:match("^([^:]+)")
    if not LINK_TIPS[kind] then return end
    GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
    if pcall(GameTooltip.SetHyperlink, GameTooltip, link) then GameTooltip:Show() else GameTooltip:Hide() end
end

local function onLinkLeave(self)
    if GameTooltip:GetOwner() == self then GameTooltip:Hide() end
end

local function newRow(self, kind)
    local r = CreateFrame("Frame", nil, self.content)
    r.kind = kind
    if kind == "day" then
        r.label = W.Text(r, "section", "muted")
        r.label:SetPoint("CENTER", 0, -1)
        r.left = W.Fill(r, "hairSoft", "BORDER")
        r.right = W.Fill(r, "hairSoft", "BORDER")
    elseif kind == "new" then
        r.label = W.Text(r, "badge", "accent")
        r.label:SetPoint("RIGHT", 0, -3)
        r.label:SetText(L["New"]:upper())
        r.line = W.Fill(r, "accentLine", "BORDER")
        r.line:SetPoint("LEFT", 0, -3)
        r.line:SetPoint("RIGHT", r.label, "LEFT", -8, 0)
        W.Paint(r.line, function(t)
            t:SetColorTexture(ns.Theme.Color("accentLine"))
            t:SetHeight(W.Pixel(r))
        end)
    elseif kind == "head" then
        r.name = W.Text(r, "bold", "text")
        r.name:SetPoint("TOPLEFT", 0, -9)
        r.time = W.Text(r, "time", "muted")
        r.time:SetPoint("BOTTOMLEFT", r.name, "BOTTOMRIGHT", 6, 1)
    elseif kind == "line" then
        r:SetHyperlinksEnabled(true)
        r:SetScript("OnHyperlinkClick", onLinkClick)
        r:SetScript("OnHyperlinkEnter", onLinkEnter)
        r:SetScript("OnHyperlinkLeave", onLinkLeave)
        r.text = W.Text(r, "body", "text")
        r.text:SetPoint("TOPLEFT")
        r.text:SetPoint("TOPRIGHT")
        r.text:SetWordWrap(true)
        r.text:SetNonSpaceWrap(true)
    else -- sys
        r:SetHyperlinksEnabled(true)
        r:SetScript("OnHyperlinkClick", onLinkClick)
        r.icon = W.Icon(r, "moon", 12, "muted")
        r.icon:SetPoint("TOPLEFT", 0, -9)
        r.text = W.Text(r, "small", "muted")
        r.text:SetPoint("TOPLEFT", 18, -7)
        r.text:SetPoint("TOPRIGHT", 0, -7)
        r.text:SetWordWrap(true)
    end
    return r
end

local SYS_ICON = { afk = "moon", dnd = "moon", notfound = "offline", ignored = "warn" }

local function fillRow(self, r, it)
    if it.kind == "day" then
        r.label:SetText(it.text:upper())
        local lw = r.label:GetStringWidth() / 2 + 8
        r.left:ClearAllPoints()
        r.left:SetPoint("LEFT", r, "LEFT", 0, -1)
        r.left:SetPoint("RIGHT", r, "CENTER", -lw, -1)
        r.right:ClearAllPoints()
        r.right:SetPoint("LEFT", r, "CENTER", lw, -1)
        r.right:SetPoint("RIGHT", r, "RIGHT", 0, -1)
        local px = W.Pixel(r)
        r.left:SetHeight(px)
        r.right:SetHeight(px)
    elseif it.kind == "head" then
        local msg = it.msg
        if msg.d == "o" then
            r.name:SetText(L["You"])
            W.SetTextColor(r.name, "accent")
        else
            r.name:SetText(ns.Names.Short(ns.Contacts.Name(self.conv)))
            local cr, cg, cb = ns.Contacts.Color(self.conv)
            W.SetTextColor(r.name, { cr, cg, cb })
        end
        r.time:SetText(ns.Format.Time(msg.t))
    elseif it.kind == "line" then
        r.text:SetText(lineText(it.msg))
    elseif it.kind == "sys" then
        r.text:SetText(it.msg.m or "")
        r.icon:SetTexture(W.MEDIA .. "Icons\\" .. (SYS_ICON[it.msg.s] or "warn"))
    end
end

local function release(self)
    for _, r in ipairs(self.rows) do
        r:Hide()
        local p = self.pools[r.kind]
        p[#p + 1] = r
    end
    self.rows = {}
end

-------------------------------------------------------------------------------
--  Render
-------------------------------------------------------------------------------
function Log:Render()
    local content = self.content
    release(self)
    local view = content:GetHeight()
    local total = self.total
    local maxOff = max(0, total - view)
    self.offset = max(0, min(self.offset, maxOff))
    local viewTop = total - view - self.offset
    for _, it in ipairs(self.items) do
        if it.top + it.h > viewTop and it.top < viewTop + view then
            local p = self.pools[it.kind]
            local r = table.remove(p) or newRow(self, it.kind)
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -(it.top - viewTop))
            r:SetPoint("RIGHT", content, "RIGHT", 0, 0)
            r:SetHeight(it.h)
            fillRow(self, r, it)
            r:Show()
            self.rows[#self.rows + 1] = r
        end
    end
    local thumb = self.thumb
    if total > view and view > 0 then
        local h = max(16, view * view / total)
        local pos = (maxOff > 0) and ((maxOff - self.offset) / maxOff) * (view - h) or 0
        thumb:ClearAllPoints()
        thumb:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", -3, -(PAD_TOP + pos))
        thumb:SetHeight(h)
        thumb:Show()
    else
        thumb:Hide()
    end
    if self.offset <= 0 then self.jump:Hide() end
end

-- remeasure: the text size or the font changed (every log's heights go).
function Log:Refresh(remeasure)
    if remeasure then for k in pairs(heights) do heights[k] = nil end end
    build(self)
    layout(self)
    self:Render()
end

function Log:SetConv(c, firstUnread)
    -- The New line goes with its message (not its place: the oldest go at 400,
    -- Clear history empties the list).
    self.conv, self.offset = c, 0
    self.newMsg = (c and firstUnread) and c.msgs[firstUnread] or nil
    self.jump:Hide()
    self:Refresh()
end

function Log:Clear()
    self.conv, self.newMsg = nil, nil
    self:Refresh()
end

-- A message arrived in the shown conversation.
function Log:OnMessage(c)
    if c ~= self.conv then return end
    local before = self.total
    build(self)
    layout(self)
    if self.offset > 0 then
        self.offset = self.offset + (self.total - before)
        self.jump:Show()
    end
    self:Render()
end

-- Whispers came in unseen (a faded or covered window): the New line goes above
-- the first of them; scrolled back, the place stays.
function Log:SetNew(i)
    self.newMsg = self.conv and self.conv.msgs[i] or nil
    local before = self.total
    build(self)
    layout(self)
    if self.offset > 0 then self.offset = self.offset + (self.total - before) end
    self:Render()
end

function Log:Scroll(delta)
    local step = IsShiftKeyDown() and self.content:GetHeight() * 0.9 or 40
    self.offset = self.offset + delta * step
    self:Render()
end

function Log:ScrollToBottom()
    self.offset = 0
    self:Render()
end

-------------------------------------------------------------------------------
--  Build
-------------------------------------------------------------------------------
function Lg.New(f)
    local self = setmetatable({
        frame = f, items = {}, rows = {}, offset = 0, total = 0,
        pools = { day = {}, new = {}, head = {}, line = {}, sys = {} },
    }, Log)
    f:EnableMouseWheel(true)
    f:SetScript("OnMouseWheel", function(_, delta) self:Scroll(delta) end)
    local content = CreateFrame("Frame", nil, f)
    content:SetPoint("TOPLEFT", PAD_X, -PAD_TOP)
    content:SetPoint("BOTTOMRIGHT", -PAD_X, PAD_BOTTOM)
    content:SetClipsChildren(true)
    self.content = content

    local measure = W.Text(content, "body", "text")
    measure:SetWordWrap(true)
    measure:SetNonSpaceWrap(true)
    measure:SetAlpha(0)
    measure:SetPoint("TOPLEFT", content, "BOTTOMLEFT", 0, -50)
    self.measure = measure
    local measureSmall = W.Text(content, "small", "muted")
    measureSmall:SetWordWrap(true)
    measureSmall:SetAlpha(0)
    measureSmall:SetPoint("TOPLEFT", content, "BOTTOMLEFT", 0, -50)
    self.measureSmall = measureSmall

    local thumb = W.Fill(f, "scroll", "ARTWORK")
    thumb:SetWidth(2)
    thumb:Hide()
    self.thumb = thumb

    local jump = CreateFrame("Button", nil, f)
    jump:SetSize(118, 20)
    jump:SetPoint("BOTTOM", 0, 10)
    jump:SetFrameLevel(f:GetFrameLevel() + 5)
    jump.pill = W.Pill(jump, 20, "accent")
    jump.pill:SetAllPoints()
    jump.icon = W.Icon(jump, "down", 11, "onAccent", "OVERLAY")
    jump.icon:SetPoint("LEFT", 10, 0)
    jump.text = W.Text(jump, "badge", "onAccent")
    jump.text:SetPoint("LEFT", jump.icon, "RIGHT", 5, 0)
    jump.text:SetText(L["New messages"])
    jump:SetScript("OnClick", function() self:ScrollToBottom() end)
    jump:Hide()
    self.jump = jump

    logs[#logs + 1] = self
    return self
end

ns.Listen("LOOKS_CHANGED", function()
    for k in pairs(heights) do heights[k] = nil end
    for _, log in ipairs(logs) do log:Refresh() end
end)
