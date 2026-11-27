-------------------------------------------------------------------------------
--  Sotto: separate windows ("Separate windows" in the settings, off by
--  default): every conversation in its own window, as WIM does. A window is
--  the approved chat column (UI/Pane.lua) with the conversation's class tile
--  in its header and "–" as its last button: a click minimises it (hidden,
--  its frame back in the pool; the conversation stays, its badge in the
--  dock), shift-click closes the conversation and deletes its history, draft
--  and saved place (WIM's shift-click); while shift is held over it the dash
--  turns into a red cross. With Keep windows open off, Esc minimises every
--  window.
--  A window counts as seen while no window brought up after it lies over a
--  quarter of it or more; its whispers count read while someone has been at it
--  in the last 4 s (Fade when idle): one into a faded window waits for the mouse
--  over it or its keyboard, even when it brings the window to the front.
--  The first window opens where the window's chat column would be, at its
--  size; the next ones step down and right. A window the player moves or
--  resizes keeps that place for its conversation (conv.win: the corner in
--  UIParent's units, the size in its own), so it comes back there.
--    ns.Windows.Open(conv, opts)   shows its window (makes one), raises it;
--                                  opts.focus, opts.text as for the window;
--                                  opts.at = { x, y }: where a new one goes
--                                  without a saved place (a login brings it back)
--    ns.Windows.Minimise(conv), ns.Windows.Close(conv)
--    ns.Windows.For(conv) -> win   its window while shown (win.frame, win.pane); nil once
--                                  minimised (the frame went back to the pool)
--    ns.Windows.IsOpen(conv)       its window is shown
--    ns.Windows.Sees(conv)         ... and not covered by one brought up later
--    ns.Windows.Reads(conv)        ... and someone has been at it lately (a whisper is read)
--    ns.Windows.Flash(conv)        a whisper for it: it lights up
--    ns.Windows.TypingElsewhere(conv)  a box of another window has the keyboard
--    ns.Windows.AnyShown(), ns.Windows.OnScreen() -> { conv }
--    ns.Windows.Front() -> conv    the shown one brought up last
--    ns.Windows.Shown()            { { conv, x, y } } of the shown ones, the front one last
--    ns.Windows.NewConversation()  a window asking for a name ("+")
--    ns.Windows.CancelPrompts(), ns.Windows.HideAll(), ns.Windows.ReleaseAll()
--    ns.Windows.FocusNext(conv)    Tab: the next open window's box
--  UI/Window.lua sends the conversations here while the setting is on.
-------------------------------------------------------------------------------
local _, ns = ...
local Wn = {}
ns.Windows = Wn

local W, L = ns.W, ns.L
local floor, abs = math.floor, math.abs

local RAIL_W = 46
local STEP = 26                 -- the cascade's step, in the window's units
local DASH = W.MEDIA .. "Icons\\minimise"
local CROSS = W.MEDIA .. "Icons\\close"

local all = {}                  -- every window made (frames are never destroyed)
local byKey = {}                -- conv.key -> its window
Wn.all = all
local raised = 0

-------------------------------------------------------------------------------
--  Places
-------------------------------------------------------------------------------
-- Where the window's chat column is: its corner in UIParent's units, its size
-- in the window's.
local function origin()
    local g = (ns.DB and ns.DB.window) or ns.DEFAULTS.window
    local s = W.Scale()
    return (g.x or 22) + RAIL_W * s, g.y or 328, (g.w or 410) - RAIL_W, g.h or 306
end

local function taken(x, y, except)
    for _, o in ipairs(all) do
        if o ~= except and o.frame:IsShown() and o.at and abs(o.at[1] - x) < 1 and abs(o.at[2] - y) < 1 then
            return true
        end
    end
    return false
end

local function anchor(w)
    local s = W.Scale()
    w.frame:ClearAllPoints()
    w.frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", w.at[1] / s, w.at[2] / s)
end

-- Its saved place, else `at` (where it was before a reload), else the first
-- free step from the chat column's corner.
local function place(w, at)
    local saved = w.conv and w.conv.win
    local x, y, width, height
    if type(saved) == "table" and saved.x and saved.y then
        x, y, width, height = saved.x, saved.y, saved.w, saved.h
    elseif type(at) == "table" and at[1] and at[2] and not taken(at[1], at[2], w) then
        x, y = at[1], at[2]
    else
        local s = W.Scale()
        local ox, oy, ow, oh = origin()
        x, y, width, height = ox, oy, ow, oh
        local k = 0
        while k < 30 and taken(x, y, w) do
            k = k + 1
            x, y = ox + k * STEP * s, oy - k * STEP * s
        end
    end
    local _, _, ow, oh = origin()
    w.frame:SetSize(width or ow, height or oh)
    w.at = { x, y }
    anchor(w)
end

-- Moved or resized by the player: the place is theirs for this conversation.
local function save(w)
    local f = w.frame
    local left, bottom = f:GetLeft(), f:GetBottom()
    if not left or not bottom then return end
    local s = W.Scale() -- GetLeft and GetBottom are in the window's units
    w.at = { floor(left * s + 0.5), floor(bottom * s + 0.5) }
    anchor(w)
    if w.conv then
        w.conv.win = { x = w.at[1], y = w.at[2], w = floor(f:GetWidth() + 0.5), h = floor(f:GetHeight() + 0.5) }
    else
        w.moved = true -- an asking window: the place becomes its conversation's
    end
end

-------------------------------------------------------------------------------
--  The dash: minimise, or with shift close and delete
-------------------------------------------------------------------------------
local function paintDash(b, hovered)
    local shift = hovered and IsShiftKeyDown()
    b.icon:SetTexture(shift and CROSS or DASH)
    W.SetIconColor(b.icon, shift and "danger" or (hovered and "text" or b.restColor))
    if not hovered then return end
    if shift then
        W.Tip(b, L["Close and delete history"])
    else
        W.Tip(b, L["Minimise"], { L["Shift-click: close and delete history"] })
    end
end

local function styleDash(b)
    b:SetScript("OnEnter", function(self)
        self.hover:Show()
        self:RegisterEvent("MODIFIER_STATE_CHANGED")
        paintDash(self, true)
    end)
    b:SetScript("OnLeave", function(self)
        self.hover:Hide()
        self:UnregisterEvent("MODIFIER_STATE_CHANGED")
        paintDash(self, false)
        W.HideTip(self)
    end)
    b:SetScript("OnEvent", function(self) paintDash(self, true) end)
end

-------------------------------------------------------------------------------
--  Windows
-------------------------------------------------------------------------------
-- Brought up: raised above the others (the one brought up last is in front).
local function front(w)
    raised = raised + 1
    w.raised = raised
    w.frame:Raise()
end

-- The window lets go of its conversation and goes back to the pool.
local function release(w)
    w.used = false
    if w.frame:IsShown() then w.frame:Hide() end -- saves the draft (OnHide)
    w.pane.compose:SetConv(nil)                  -- the box lets go of it
    w.pane:ClosePrompt()
    w.pane.log:Clear()
    w.pane.composeFrame:Show()
    w.pane.conv = nil
    if w.conv and byKey[w.conv.key] == w then byKey[w.conv.key] = nil end
    w.conv, w.moved, w.raised = nil, nil, nil
end

-- Another shown window brought up after this one lies over a quarter of it or more.
local function covered(w)
    local f = w.frame
    local l, b, r, t = f:GetLeft(), f:GetBottom(), f:GetRight(), f:GetTop()
    if not (l and b and r and t) or r <= l or t <= b then return false end
    for _, o in ipairs(all) do
        if o ~= w and o.used and o.frame:IsShown() and (o.raised or 0) > (w.raised or 0) then
            local of = o.frame
            local ol, ob, orr, ot = of:GetLeft(), of:GetBottom(), of:GetRight(), of:GetTop()
            if ol and ob and orr and ot then
                local iw = math.min(r, orr) - math.max(l, ol)
                local ih = math.min(t, ot) - math.max(b, ob)
                if iw > 0 and ih > 0 and iw * ih * 4 >= (r - l) * (t - b) then return true end
            end
        end
    end
    return false
end

-- A window went away or moved: what is in view now is read, unless it is faded
-- (then it waits for a look).
local function readUncovered()
    for _, o in ipairs(all) do
        if o.conv and o.frame:IsShown() and (o.conv.unread or 0) > 0 and not covered(o)
            and not o.fader:Idle() then
            ns.Store.MarkRead(o.conv)
        end
    end
end

-- Brought up by the player (a click, the keyboard): in front, and read.
local function touched(w)
    front(w)
    w.fader:Wake()
    if w.conv then ns.Store.MarkRead(w.conv) end
end

local pick -- Enter in an asking window's name field

local function newWindow()
    local n = #all + 1
    local name = "SottoConv" .. n
    local f = W.Scaled(CreateFrame("Frame", name, UIParent))
    f:SetSize(364, 306)
    f:SetFrameStrata("MEDIUM")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:SetResizable(true)
    if f.SetResizeBounds then f:SetResizeBounds(260, 200, 900, 720) end
    if f.SetDontSavePosition then f:SetDontSavePosition(true) end
    f:EnableMouse(true)
    f:Hide()
    W.Escapable(name) -- Esc minimises it only with Keep windows open off
    f.bg = W.Fill(f, "bg", "BACKGROUND", -7)
    f.bg:SetAllPoints()
    W.Shadow(f, 16, 0.55)
    W.Outline(f, "edge")
    W.Border(f, "hair", "OVERLAY")

    local w = { frame = f, index = n }
    w.pane = ns.Pane.New(f, {
        tile = true,
        icon = DASH,
        tip = L["Minimise"],
        onClose = function()
            if not w.conv then return end
            if IsShiftKeyDown() then Wn.Close(w.conv) else Wn.Minimise(w.conv) end
        end,
        onPick = function(_, typed) pick(w, typed) end,
        onCancel = function() release(w) end,
        closeItem = function(p)
            return { text = L["Close and delete history"], color = "danger", func = function() Wn.Close(p.conv) end }
        end,
        move = {
            start = function()
                touched(w)
                f:StartMoving()
            end,
            stop = function()
                f:StopMovingOrSizing()
                save(w)
                readUncovered()
            end,
        },
    })
    styleDash(w.pane.head.close)
    f:SetScript("OnMouseDown", function() touched(w) end)

    local grip = CreateFrame("Button", nil, f)
    grip:SetSize(12, 12)
    grip:SetPoint("BOTTOMRIGHT", -2, 2)
    grip:SetFrameLevel(f:GetFrameLevel() + 20)
    grip.tex = grip:CreateTexture(nil, "OVERLAY")
    grip.tex:SetTexture(W.MEDIA .. "grip")
    grip.tex:SetAllPoints()
    grip.tex:SetAlpha(0.35)
    grip:SetScript("OnEnter", function(self) self.tex:SetAlpha(0.7) end)
    grip:SetScript("OnLeave", function(self) self.tex:SetAlpha(0.35) end)
    grip:SetScript("OnMouseDown", function() f:StartSizing("BOTTOMRIGHT") end)
    grip:SetScript("OnMouseUp", function()
        f:StopMovingOrSizing()
        save(w)
    end)
    w.grip = grip

    -- The player at the window reads it, unless another lies over it.
    w.fader = W.Fader(f, function() return w.pane.compose:HasFocus() or w.pane.prompt.edit:HasFocus() end, function()
        local c = w.conv
        if c and (c.unread or 0) > 0 and not covered(w) then ns.Store.MarkRead(c) end
    end)
    f:SetScript("OnShow", function()
        w.fader:Start()
        ns.Contacts.ScheduleRefresh()
    end)
    -- Hidden (the dash, Esc, the gamepad interface): minimised, the frame goes
    -- back to the pool. The dash under the cursor may never hear OnLeave.
    f:SetScript("OnHide", function()
        w.fader:Stop()
        local compose = w.pane.compose
        compose:SaveDraft()
        if compose:HasFocus() then compose.box:ClearFocus() end
        local dash = w.pane.head.close
        dash:UnregisterEvent("MODIFIER_STATE_CHANGED")
        dash.hover:Hide()
        paintDash(dash, false)
        W.HideTip(dash)
        local menu = W.CurrentMenu()
        if menu and menu:IsShown() and menu.anchor == w.pane.head.more then W.CloseMenu() end
        -- Hidden with the interface (Alt+Z, a cinematic): it comes back with it.
        if f:IsShown() then return end
        if w.used then release(w) end
        readUncovered()
        ns.Rail.Refresh()
    end)
    f:SetScript("OnSizeChanged", function() w.pane.log:Refresh() end)
    w.pane:Layout()

    all[n] = w
    return w
end

local function acquire()
    for _, w in ipairs(all) do
        if not w.used then
            w.used = true
            return w
        end
    end
    local w = newWindow()
    w.used = true
    return w
end

-------------------------------------------------------------------------------
--  API
-------------------------------------------------------------------------------
function Wn.For(conv)
    return conv and byKey[conv.key] or nil
end

function Wn.IsOpen(conv)
    local w = Wn.For(conv)
    return w ~= nil and w.frame:IsShown()
end

function Wn.Sees(conv)
    local w = Wn.For(conv)
    return w ~= nil and w.frame:IsShown() and not covered(w)
end

-- ... and someone has been at it lately: a whisper into a faded window counts
-- unread until the player looks.
function Wn.Reads(conv)
    local w = Wn.For(conv)
    return w ~= nil and w.frame:IsShown() and not covered(w) and not w.fader:Idle()
end

-- The player is typing in another window (its box or its name field).
function Wn.TypingElsewhere(conv)
    for _, w in ipairs(all) do
        if w.used and w.frame:IsShown() and (not conv or w.conv ~= conv) then
            if w.pane.compose:HasFocus() or w.pane.prompt.edit:HasFocus() then return true end
        end
    end
    return false
end

function Wn.AnyShown()
    for _, w in ipairs(all) do
        if w.frame:IsShown() then return true end
    end
    return false
end

function Wn.OnScreen()
    local out = {}
    for _, w in ipairs(all) do
        if w.conv and w.frame:IsShown() then out[#out + 1] = w.conv end
    end
    return out
end

-- The shown windows, the one brought up last at the end: { { conv, x, y } }
-- (x, y: the corner in UIParent's units).
function Wn.Shown()
    local up = {}
    for _, w in ipairs(all) do
        if w.conv and w.frame:IsShown() then up[#up + 1] = w end
    end
    table.sort(up, function(a, b) return (a.raised or 0) < (b.raised or 0) end)
    local out = {}
    for i, w in ipairs(up) do out[i] = { conv = w.conv, x = w.at and w.at[1], y = w.at and w.at[2] } end
    return out
end

function Wn.Front()
    local best
    for _, w in ipairs(all) do
        if w.conv and w.frame:IsShown() and (not best or (w.raised or 0) > (best.raised or 0)) then best = w end
    end
    return best and best.conv or nil
end

function Wn.Typing(conv)
    local w = Wn.For(conv)
    return w ~= nil and w.frame:IsShown() and w.pane.compose:HasFocus()
end

function Wn.Open(conv, opts)
    if not conv then return end
    if type(opts) ~= "table" then opts = {} end
    if not conv.open then
        conv.open = true -- starting a closed conversation again brings it back
        ns.Fire("CONV_UPDATED", conv)
    end
    local w = byKey[conv.key]
    if not w then
        w = acquire()
        w.conv = conv
        byKey[conv.key] = w
        place(w, opts.at)
    end
    local f = w.frame
    if not f:IsShown() or w.pane.conv ~= conv then
        w.pane.composeFrame:Show()
        f:Show()
        w.pane:SetConv(conv) -- the New line, read, the contact refreshed
    elseif not (opts.whisper and w.fader:Idle()) then
        ns.Store.MarkRead(conv) -- brought up by a whisper while nobody is at it: unread
    end
    front(w)
    if opts.text then w.pane.compose:SetText(opts.text) end
    if opts.focus then w.pane.compose:Focus() end
    if opts.whisper then w.fader:Flash() else w.fader:Wake() end
    ns.Toast.HideFor(conv)
    ns.Rail.Refresh()
    return w
end

function Wn.Minimise(conv)
    local w = Wn.For(conv)
    if w and w.frame:IsShown() then w.frame:Hide() end -- OnHide gives the frame back
end

-- Closed for good: the window goes, and with it the history, the draft and
-- the saved place (Store.Forget).
function Wn.Close(conv)
    if not conv then return end
    local w = byKey[conv.key]
    if w then release(w) end
    ns.Compose.DropDraft(conv.key) -- after release: hiding saved it
    ns.Engine.DropEchoes(conv)     -- lines still on their way stay out of it
    ns.Toast.HideFor(conv)
    ns.Store.Forget(conv)
    ns.Rail.Refresh()
end

-- "+": a window asking for a name, at the next free step.
function Wn.NewConversation()
    for _, w in ipairs(all) do
        if w.used and not w.conv then
            front(w)
            w.pane:ShowPrompt()
            return w
        end
    end
    local w = acquire()
    w.pane.compose:SetConv(nil)
    w.pane.log:Clear()
    w.pane.composeFrame:Hide() -- the name first
    place(w)
    w.frame:Show()
    front(w)
    w.pane:ShowPrompt()
    return w
end

pick = function(w, typed)
    local conv = typed and ns.Store.Ensure("w", typed)
    if not conv then return release(w) end
    local other = byKey[conv.key]
    if other and other ~= w then
        release(w)
        return Wn.Open(conv, { focus = true })
    end
    w.conv = conv
    byKey[conv.key] = w
    if w.moved then save(w) end
    Wn.Open(conv, { focus = true })
end

function Wn.CancelPrompts()
    for _, w in ipairs(all) do
        if w.used and not w.conv then release(w) end
    end
end

function Wn.HideAll()
    for _, w in ipairs(all) do
        if w.frame:IsShown() then w.frame:Hide() end
    end
end

-- The setting went off: every window lets go of its conversation (drafts and
-- saved places stay).
function Wn.ReleaseAll()
    for _, w in ipairs(all) do
        if w.used then release(w) end
    end
end

-- Tab: the next open window, in the rail's order.
function Wn.FocusNext(conv)
    local open = {}
    for _, c in ipairs(ns.Store.List()) do
        local w = byKey[c.key]
        if w and w.frame:IsShown() then open[#open + 1] = w end
    end
    if #open < 2 then return end
    local at = 0
    for i, w in ipairs(open) do if w.conv == conv then at = i end end
    local nextWin = open[at % #open + 1]
    front(nextWin)
    nextWin.pane.compose:Focus()
end

-------------------------------------------------------------------------------
--  Events (the window sends them here while the setting is on)
-------------------------------------------------------------------------------
-- A whisper for a conversation whose window is on screen: it wakes up.
-- A whisper for a window in view: it lights up (the player is no nearer).
function Wn.Flash(conv)
    local w = Wn.For(conv)
    if w and w.frame:IsShown() then w.fader:Flash() end
end

-- Whispers came in unseen (a faded or covered window): the New line above the first.
ns.Listen("UNREAD_CHANGED", function(conv)
    local w = Wn.For(conv)
    if w and w.frame:IsShown() and w.pane.conv == conv and (conv.unread or 0) > 0 then w.pane:MarkNew() end
end)

function Wn.OnMessage(conv)
    local w = Wn.For(conv)
    if w and w.frame:IsShown() and w.pane.conv == conv then w.pane.log:OnMessage(conv) end
end

-- conv nil: every conversation may have changed (pruning).
function Wn.OnUpdate(conv)
    for _, w in ipairs(all) do
        local c = w.conv
        if c and (conv == nil or c == conv) then
            if not c.open then
                release(w) -- closed elsewhere (a report, the rail): the window goes, its draft stays
            elseif w.frame:IsShown() and w.pane.conv == c then
                w.pane.log:Refresh()
                w.pane:UpdateHeader()
            end
        end
    end
end

function Wn.OnContact(conv)
    for _, w in ipairs(all) do
        if w.conv and w.frame:IsShown() and (conv == nil or w.conv == conv) then w.pane:UpdateHeader() end
    end
end

ns.Listen("COMPOSE_FOCUS", function(focused, compose)
    if not focused then return end
    for _, w in ipairs(all) do
        if w.used and w.pane.compose == compose then touched(w) end
    end
end)

ns.Listen("SCALE_CHANGED", function()
    for _, w in ipairs(all) do
        if w.used and w.at then anchor(w) end
    end
end)

ns.Listen("SETTING_CHANGED", function(key)
    if key ~= "fadeIdle" then return end
    for _, w in ipairs(all) do w.fader:Wake() end
end)
