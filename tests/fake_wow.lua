-------------------------------------------------------------------------------
--  Sotto -- fake WoW environment for offline tests (LuaJIT / Lua 5.1)
--
--  F.new() builds a fresh global table that looks like the WoW Forever client
--  (Interface 16001, 12.1 engine) as far as Sotto touches it. Widgets resolve
--  their anchors into rectangles, font strings have deterministic metrics,
--  events and timers run on demand, and secret values behave like the real
--  ones where Lua lets us: string functions refuse them and SetText raises.
--  The chat pieces copy the order of Blizzard's own code (forever branch,
--  build 1.60.1): chat frames run message filters before any addon frame
--  sees an event, and ReplyTell calls UpdateHeader before it opens the box.
-------------------------------------------------------------------------------
local F = {}

local unpack = unpack or table.unpack
local function pack(...) return { n = select("#", ...), ... } end

-------------------------------------------------------------------------------
--  Secret values: opaque userdata. Arithmetic, indexing, length and tostring
--  raise; concatenation yields another secret (allowed in the real client).
-------------------------------------------------------------------------------
local secretMT
local secrets = setmetatable({}, { __mode = "k" })
local function newSecret(v)
    local s = newproxy(true)
    local mt = getmetatable(s)
    for k, f in pairs(secretMT) do mt[k] = f end
    secrets[s] = v
    return s
end
local function boom(what) return function() error("attempt to " .. what .. " a secret value", 2) end end
secretMT = {
    __index = boom("index"), __newindex = boom("index"), __len = boom("get the length of"),
    __add = boom("perform arithmetic on"), __sub = boom("perform arithmetic on"),
    __mul = boom("perform arithmetic on"), __div = boom("perform arithmetic on"),
    __lt = boom("compare"), __le = boom("compare"), __tostring = boom("convert"),
    __call = boom("call"),
    __concat = function(a, b) return newSecret("<concat>") end,
}
F.secret = newSecret
local function isSecret(v) return type(v) == "userdata" and secrets[v] ~= nil end
F.isSecret = isSecret

-------------------------------------------------------------------------------
--  The environment
-------------------------------------------------------------------------------
function F.new(opts)
    opts = opts or {}
    local G = {}
    local W = {}            -- harness-only state, also reachable as G.__T
    G.__T = W
    W.globalsWritten = {}
    W.events = {}           -- event -> list of frames
    W.timers = {}
    W.clock = 1000          -- GetTime()
    W.epoch = 1794499200    -- time(): 2026-11-12 14:00 UTC-ish
    W.sent = {}             -- C_ChatInfo.SendChatMessage calls
    W.bnSent = {}
    W.sounds = {}
    W.flashes = 0
    W.chatLog = {}          -- what Blizzard's chat frame displayed
    W.combat = false
    W.lockdown = false
    W.cvars = { whisperMode = "inline", timeMgrUseMilitaryTime = "1", chatStyle = "classic" }
    W.loadedAddons = { Sotto = true }
    W.disabledAddons = {}
    W.reloads = 0
    W.chatLines = {}        -- lineID -> { text, sender, guid }
    W.guids = {}            -- guid -> { classLoc, classFile, raceLoc, raceFile, sex, name, realm }
    W.friends = {}          -- list of C_FriendList infos
    W.guild = {}            -- list of roster rows
    W.bnFriends = {}        -- list of C_BattleNet account infos
    W.focus = nil
    W.atlases = {}

    -- Lua standard library as WoW exposes it (no io/os/debug/jit/bit).
    for _, k in ipairs({ "assert", "error", "ipairs", "next", "pairs", "pcall", "print", "rawequal", "rawget",
        "rawset", "select", "setmetatable", "getmetatable", "tonumber", "tostring", "type", "unpack", "xpcall",
        "string", "table", "math", "coroutine", "loadstring" }) do
        G[k] = _G[k]
    end
    G._G = G
    G.date = os.date
    G.time = function(t) if t then return os.time(t) end return W.epoch + math.floor(W.clock - 1000) end
    G.GetServerTime = G.time
    G.GetTime = function() return W.clock end
    G.debugprofilestop = function() return W.clock * 1000 end
    G.strsub, G.strlen, G.strupper, G.strlower = string.sub, string.len, string.upper, string.lower
    G.strfind, G.strmatch, G.gsub, G.format, G.strrep, G.strbyte, G.strchar = string.find, string.match, string.gsub,
        string.format, string.rep, string.byte, string.char
    G.strtrim = function(s, chars)
        chars = chars or " \t\r\n"
        local p = "[" .. chars:gsub("[%]%^%-]", "%%%0") .. "]"
        return (s:gsub("^" .. p .. "+", ""):gsub(p .. "+$", ""))
    end
    G.strsplit = function(sep, s, limit)
        local out, start = {}, 1
        while true do
            local i, j = string.find(s, sep, start, true)
            if not i or (limit and #out == limit - 1) then out[#out + 1] = string.sub(s, start); break end
            out[#out + 1] = string.sub(s, start, i - 1)
            start = j + 1
        end
        return unpack(out)
    end
    G.tinsert, G.tremove, G.tconcat, G.sort = table.insert, table.remove, table.concat, table.sort
    G.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
    G.floor, G.ceil, G.abs, G.min, G.max, G.sqrt, G.random = math.floor, math.ceil, math.abs, math.min, math.max,
        math.sqrt, math.random
    G.issecretvalue = function(v) return isSecret(v) end
    G.hasanysecretvalues = function(...)
        for i = 1, select("#", ...) do if isSecret((select(i, ...))) then return true end end
        return false
    end
    G.canaccessvalue = function(...) return not G.hasanysecretvalues(...) end
    G.scrubsecretvalues = function(...)
        local out = pack(...)
        for i = 1, out.n do if isSecret(out[i]) then out[i] = nil end end
        return unpack(out, 1, out.n)
    end
    G.geterrorhandler = function() return function(err) W.lastError = err; error(err, 0) end end
    G.securecallfunction = function(fn, ...) return fn(...) end
    G.hooksecurefunc = function(tbl, name, hook)
        if type(tbl) == "string" then tbl, name, hook = G, tbl, name end
        local orig = tbl[name]
        assert(type(orig) == "function", "hooksecurefunc: no function " .. tostring(name))
        tbl[name] = function(...)
            local r = pack(orig(...))
            hook(...)
            return unpack(r, 1, r.n)
        end
    end

    ---------------------------------------------------------------------------
    --  Widgets
    ---------------------------------------------------------------------------
    local named = {}
    local Object = {}
    Object.__index = Object

    W.allFrames = {}
    local function newObject(kind, name, parent)
        local o = setmetatable({ _type = kind, _name = name, _parent = parent, _points = {}, _shown = true,
            _alpha = 1, _scripts = {}, _attrs = {}, _children = {}, _regions = {}, _level = 1, _scale = 1 }, Object)
        if parent and parent._children then
            if kind == "Texture" or kind == "FontString" or kind == "Line" then
                parent._regions[#parent._regions + 1] = o
            else
                parent._children[#parent._children + 1] = o
                o._level = (parent._level or 0) + 1
            end
        end
        if kind ~= "Texture" and kind ~= "FontString" and kind ~= "Line" then
            W.allFrames[#W.allFrames + 1] = o
        end
        if name then
            name = name:gsub("%$parent", parent and parent._name or "")
            o._name = name
            named[name] = o
            rawset(G, name, o)
        end
        return o
    end
    W.named = named

    -- geometry --------------------------------------------------------------
    local function pointXY(rect, p)
        local l, b, w, h = rect[1], rect[2], rect[3], rect[4]
        local x = p:find("LEFT") and l or (p:find("RIGHT") and l + w) or l + w / 2
        local y = p:find("TOP") and b + h or (p:find("BOTTOM") and b) or b + h / 2
        return x, y
    end
    local resolving = {}
    local function rectOf(o)
        if o._isRoot then return { 0, 0, 1920, 1080 } end
        -- A scroll child hangs from its scroll frame's top-left, moved by the scroll.
        if o._scrollParent and #o._points == 0 then
            local p = rectOf(o._scrollParent)
            local h = o._h or 0
            return { p[1], p[2] + p[4] - h + (o._scrollParent._vscroll or 0), o._w or 0, h }
        end
        if resolving[o] then return { 0, 0, o._w or 0, o._h or 0 } end
        resolving[o] = true
        local L, R, T, B, CX, CY
        for _, pt in ipairs(o._points) do
            local p, rel, rp, ox, oy = pt[1], pt[2], pt[3], pt[4] or 0, pt[5] or 0
            local x, y = pointXY(rectOf(rel), rp)
            x, y = x + ox, y + oy
            if p:find("LEFT") then L = x elseif p:find("RIGHT") then R = x else CX = x end
            if p:find("TOP") then T = y elseif p:find("BOTTOM") then B = y else CY = y end
        end
        resolving[o] = nil
        local w = (L and R) and (R - L) or (o._w or 0)
        local h = (T and B) and (T - B) or (o._h or 0)
        -- A font string without a set width is as wide as its text, as in the client.
        if o._type == "FontString" then
            local size = (o._font and o._font[2]) or 12
            if not (L and R) and w == 0 then w = #W.plain(o._text or "") * size * 0.5 end
            if not (T and B) and h == 0 then
                local lines = 1
                if o._wrap ~= false and ((L and R) or (o._w or 0) > 0) and w > 0 then
                    lines = math.max(1, math.ceil(#W.plain(o._text or "") * size * 0.5 / w))
                end
                h = lines * (size + 2)
            end
        end
        local l = L or (R and R - w) or (CX and CX - w / 2) or 0
        local b = B or (T and T - h) or (CY and CY - h / 2) or 0
        return { l, b, w, h }
    end
    W.rect = rectOf

    function Object:GetObjectType() return self._type end
    function Object:IsObjectType(t)
        if self._type == t then return true end
        if t == "Frame" then return self._type ~= "Texture" and self._type ~= "FontString" end
        if t == "Region" then return true end
        return false
    end
    function Object:GetName() return self._name end
    function Object:GetDebugName() return self._name or "anon" end
    function Object:IsForbidden() return false end
    function Object:IsProtected() return false end
    function Object:GetParent() return self._parent end
    function Object:SetParent(p)
        self._parent = p
        if p and p._children then p._children[#p._children + 1] = self end
    end
    function Object:SetPoint(p, rel, rp, x, y)
        if type(rel) == "number" then rel, rp, x, y = nil, nil, rel, rp end
        if type(rel) == "string" then rel = named[rel] end
        rel = rel or self._parent or G.UIParent
        rp = rp or p
        for i, old in ipairs(self._points) do
            if old[1] == p then table.remove(self._points, i); break end
        end
        self._points[#self._points + 1] = { p, rel, rp, x or 0, y or 0 }
    end
    function Object:ClearAllPoints() self._points = {} end
    function Object:SetAllPoints(rel)
        rel = rel or self._parent
        self._points = { { "TOPLEFT", rel, "TOPLEFT", 0, 0 }, { "BOTTOMRIGHT", rel, "BOTTOMRIGHT", 0, 0 } }
    end
    function Object:GetNumPoints() return #self._points end
    function Object:GetPoint(i)
        local p = self._points[i or 1]
        if p then return p[1], p[2], p[3], p[4], p[5] end
    end
    function Object:SetSize(w, h) self._w, self._h = w, h end
    function Object:SetWidth(w) self._w = w end
    function Object:SetHeight(h) self._h = h end
    function Object:GetWidth() return rectOf(self)[3] end
    function Object:GetHeight() return rectOf(self)[4] end
    function Object:GetSize() local r = rectOf(self); return r[3], r[4] end
    function Object:GetLeft() return rectOf(self)[1] end
    function Object:GetBottom() return rectOf(self)[2] end
    function Object:GetRight() local r = rectOf(self); return r[1] + r[3] end
    function Object:GetTop() local r = rectOf(self); return r[2] + r[4] end
    function Object:GetCenter() local r = rectOf(self); return r[1] + r[3] / 2, r[2] + r[4] / 2 end
    function Object:GetRect() local r = rectOf(self); return r[1], r[2], r[3], r[4] end
    function Object:Show() local was = self:IsVisible(); self._shown = true; if not was and self:IsVisible() then self:_fire("OnShow") end end
    function Object:Hide() local was = self:IsVisible(); self._shown = false; if was then self:_fire("OnHide") end end
    function Object:SetShown(v) if v then self:Show() else self:Hide() end end
    function Object:IsShown() return self._shown end
    function Object:IsVisible()
        local o = self
        while o do
            if not o._shown then return false end
            o = o._parent
        end
        return true
    end
    function Object:SetAlpha(a) self._alpha = a end
    function Object:GetAlpha() return self._alpha end
    function Object:GetEffectiveAlpha()
        local a, o = 1, self
        while o do a = a * (o._alpha or 1); o = o._parent end
        return a
    end
    function Object:SetScale(s) self._scale = s end
    function Object:GetScale() return self._scale end
    function Object:GetEffectiveScale() return self._scale * (self._parent and self._parent:GetEffectiveScale() or 1) end
    function Object:SetFrameStrata(s) self._strata = s end
    function Object:GetFrameStrata() return self._strata or "MEDIUM" end
    function Object:SetFrameLevel(l) self._level = l end
    function Object:GetFrameLevel() return self._level end
    function Object:SetDrawLayer(l, s) self._layer, self._sub = l, s end
    function Object:GetDrawLayer() return self._layer, self._sub end
    function Object:SetIgnoreParentAlpha() end
    function Object:SetIgnoreParentScale() end
    function Object:SetSnapToPixelGrid() end
    function Object:SetTexelSnappingBias() end

    -- scripts ---------------------------------------------------------------
    function Object:SetScript(event, fn) self._scripts[event] = fn end
    function Object:GetScript(event) return self._scripts[event] end
    function Object:HasScript() return true end
    function Object:HookScript(event, fn)
        local prev = self._scripts[event]
        self._scripts[event] = function(...) if prev then prev(...) end fn(...) end
    end
    function Object:_fire(event, ...)
        local fn = self._scripts[event]
        if fn then return fn(self, ...) end
    end

    -- frames ----------------------------------------------------------------
    function Object:CreateTexture(name, layer, template, sub)
        local t = newObject("Texture", name, self)
        t._layer, t._sub = layer, sub
        return t
    end
    function Object:CreateFontString(name, layer, template)
        local f = newObject("FontString", name, self)
        f._layer = layer
        f._text = ""
        if template == "GameFontNormal" or template then f._font = { "Fonts\\FRIZQT__.TTF", 12, "" } end
        return f
    end
    function Object:CreateLine(name, layer) return newObject("Line", name, self) end
    function Object:CreateAnimationGroup()
        local ag = { _anims = {}, _playing = false, _scripts = {} }
        function ag:CreateAnimation(kind)
            local a = { _kind = kind }
            setmetatable(a, { __index = function(_, k) return function() end end })
            ag._anims[#ag._anims + 1] = a
            return a
        end
        function ag:Play() ag._playing = true; local f = ag._scripts.OnPlay; if f then f(ag) end end
        function ag:Stop() ag._playing = false; local f = ag._scripts.OnStop; if f then f(ag) end end
        function ag:Finish() ag._playing = false; local f = ag._scripts.OnFinished; if f then f(ag) end end
        function ag:IsPlaying() return ag._playing end
        function ag:SetScript(e, fn) ag._scripts[e] = fn end
        function ag:SetLooping() end
        function ag:SetToFinalAlpha() end
        return ag
    end
    function Object:GetChildren() return unpack(self._children) end
    function Object:GetNumChildren() return #self._children end
    function Object:GetRegions() return unpack(self._regions) end
    function Object:RegisterEvent(e)
        W.events[e] = W.events[e] or {}
        for _, f in ipairs(W.events[e]) do if f == self then return end end
        table.insert(W.events[e], self)
    end
    function Object:RegisterUnitEvent(e) self:RegisterEvent(e) end
    function Object:UnregisterEvent(e)
        local list = W.events[e]
        if not list then return end
        for i, f in ipairs(list) do if f == self then table.remove(list, i); return end end
    end
    function Object:UnregisterAllEvents()
        for _, list in pairs(W.events) do
            for i = #list, 1, -1 do if list[i] == self then table.remove(list, i) end end
        end
    end
    function Object:IsEventRegistered(e)
        for _, f in ipairs(W.events[e] or {}) do if f == self then return true end end
        return false
    end
    function Object:EnableMouse(v) self._mouse = v end
    function Object:IsMouseEnabled() return self._mouse end
    function Object:EnableMouseWheel(v) self._wheel = v end
    function Object:EnableKeyboard(v) self._keyboard = v end
    function Object:SetPropagateKeyboardInput(v) self._propagate = v end
    function Object:SetMouseClickEnabled() end
    function Object:SetMouseMotionEnabled() end
    function Object:SetHitRectInsets() end
    function Object:SetMovable(v) self._movable = v end
    function Object:SetResizable(v) self._resizable = v end
    function Object:SetResizeBounds(a, b, c, d) self._bounds = { a, b, c, d } end
    function Object:SetClampedToScreen(v) self._clamped = v end
    function Object:SetClampRectInsets() end
    function Object:SetToplevel(v) self._toplevel = v end
    function Object:SetDontSavePosition() end
    function Object:SetUserPlaced() end
    function Object:IsUserPlaced() return false end
    function Object:RegisterForDrag() end
    function Object:StartMoving() self._moving = true end
    function Object:StartSizing() self._sizing = true end
    function Object:StopMovingOrSizing() self._moving, self._sizing = nil, nil end
    function Object:SetClipsChildren(v) self._clips = v end
    function Object:SetHyperlinksEnabled(v) self._links = v end
    function Object:Raise() end
    function Object:Lower() end
    function Object:SetID(i) self._id = i end
    function Object:GetID() return self._id or 0 end
    function Object:SetAttribute(k, v) self._attrs[k] = v end
    function Object:GetAttribute(k) return self._attrs[k] end
    function Object:IsMouseOver() return self._mouseOver == true end
    function Object:SetFixedFrameStrata() end
    function Object:SetFixedFrameLevel() end
    function Object:SetFlattensRenderLayers() end
    function Object:SetCollapsesLayout() end

    -- textures --------------------------------------------------------------
    function Object:SetTexture(path) self._texture = path; self._color = nil; return true end
    function Object:GetTexture() return self._texture end
    function Object:SetAtlas(a) self._atlas = a; return true end
    function Object:SetColorTexture(r, g, b, a) self._color = { r, g, b, a or 1 }; self._texture = nil end
    function Object:SetVertexColor(r, g, b, a) self._vertex = { r, g, b, a or 1 } end
    function Object:GetVertexColor() local v = self._vertex or { 1, 1, 1, 1 }; return v[1], v[2], v[3], v[4] end
    function Object:SetTexCoord(...) self._texcoord = { ... } end
    function Object:GetTexCoord() return unpack(self._texcoord or { 0, 1, 0, 1 }) end
    function Object:SetGradient(dir, a, b) self._gradient = { dir, a, b } end
    function Object:SetBlendMode(m) self._blend = m end
    function Object:SetDesaturated(v) self._desat = v end
    function Object:SetRotation(r) self._rot = r end
    function Object:SetHorizTile() end
    function Object:SetVertTile() end
    function Object:SetMask() end
    function Object:AddMaskTexture() end

    -- font strings / edit boxes / buttons ---------------------------------------
    local function plain(text)
        text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
        text = text:gsub("|H.-|h(.-)|h", "%1"):gsub("|T.-|t", "  "):gsub("|K.-|k", "Friend")
        return text
    end
    W.plain = plain
    function Object:SetFont(path, size, flags)
        if type(path) ~= "string" or path == "" or type(size) ~= "number" then error("SetFont: bad arguments", 2) end
        if W.missingFonts and W.missingFonts[path] then return false end
        self._font = { path, size, flags or "" }
        return true
    end
    function Object:GetFont() local f = self._font or { "Fonts\\FRIZQT__.TTF", 12, "" }; return f[1], f[2], f[3] end
    function Object:SetFontObject(o) self._fontObject = o end
    function Object:SetText(t)
        if isSecret(t) then error("SetText received a secret value", 2) end
        if t ~= nil and type(t) ~= "string" and type(t) ~= "number" then error("SetText: bad argument", 2) end
        local old = self._text
        self._text = t and tostring(t) or ""
        if self._type == "EditBox" and old ~= self._text then self:_fire("OnTextChanged", false) end
    end
    function Object:SetFormattedText(fmt, ...) self:SetText(string.format(fmt, ...)) end
    function Object:GetText() if self._type == "FontString" and self._text == "" then return nil end return self._text end
    function Object:SetTextColor(r, g, b, a) self._textColor = { r, g, b, a or 1 } end
    function Object:GetTextColor() local c = self._textColor or { 1, 1, 1, 1 }; return c[1], c[2], c[3], c[4] end
    function Object:SetJustifyH(j) self._justifyH = j end
    function Object:SetJustifyV(j) self._justifyV = j end
    function Object:SetWordWrap(v) self._wrap = v end
    function Object:SetNonSpaceWrap(v) self._nsw = v end
    function Object:SetMaxLines(n) self._maxLines = n end
    function Object:SetSpacing(s) self._spacing = s end
    function Object:SetIndentedWordWrap() end
    function Object:SetShadowOffset(x, y) self._shadow = { x, y } end
    function Object:SetShadowColor() end
    function Object:SetTextScale() end
    local function fontSize(o) return (o._font and o._font[2]) or 12 end
    function Object:GetStringWidth() return #plain(self._text or "") * fontSize(self) * 0.5 end
    function Object:GetUnboundedStringWidth() return self:GetStringWidth() end
    function Object:GetStringHeight()
        local size = fontSize(self)
        local w = rectOf(self)[3]
        local sw = self:GetStringWidth()
        local lines = 1
        if self._wrap ~= false and w > 0 then lines = math.max(1, math.ceil(sw / w)) end
        if self._maxLines and self._maxLines > 0 then lines = math.min(lines, self._maxLines) end
        return lines * (size + 2)
    end
    function Object:GetLineHeight() return fontSize(self) + 2 end
    function Object:IsTruncated() return false end
    -- edit box
    function Object:SetFocus()
        if W.focus == self then return end
        local old = W.focus
        W.focus = self
        if old then old:_fire("OnEditFocusLost") end
        self:_fire("OnEditFocusGained")
    end
    function Object:ClearFocus()
        if W.focus ~= self then return end
        W.focus = nil
        self:_fire("OnEditFocusLost")
    end
    function Object:HasFocus() return W.focus == self end
    function Object:SetAutoFocus(v) self._autofocus = v end
    function Object:SetMaxLetters(n) self._maxLetters = n end
    function Object:SetMaxBytes(n) self._maxBytes = n end
    function Object:SetMultiLine(v) self._multi = v end
    function Object:IsMultiLine() return self._multi end
    function Object:SetTextInsets(...) self._insets = { ... } end
    function Object:SetCursorPosition(p) self._cursor = p end
    function Object:GetCursorPosition() return self._cursor or #(self._text or "") end
    function Object:HighlightText() self._highlighted = true end
    function Object:Insert(t) self:SetText((self._text or "") .. t) end
    function Object:AddHistoryLine(t) self._history = self._history or {}; table.insert(self._history, t) end
    function Object:SetHistoryLines() end
    function Object:SetAltArrowKeyMode(v) self._altArrow = v end
    function Object:SetCountInvisibleLetters() end
    function Object:GetNumLetters() return #(self._text or "") end
    function Object:SetEnabled(v) self._enabled = v and true or false end
    -- buttons
    function Object:Enable() self._enabled = true end
    function Object:Disable() self._enabled = false end
    function Object:IsEnabled() return self._enabled ~= false end
    function Object:RegisterForClicks() end
    function Object:SetMotionScriptsWhileDisabled() end
    function Object:Click(button) self:_fire("OnClick", button or "LeftButton", false) end
    function Object:SetNormalTexture(t) self._normal = t end
    function Object:SetHighlightTexture(t) self._highlight = t end
    function Object:SetPushedTexture(t) self._pushed = t end
    function Object:SetDisabledTexture(t) self._disabledTex = t end
    function Object:GetNormalTexture() return self._normal end
    function Object:GetHighlightTexture() return self._highlight end
    function Object:LockHighlight() end
    function Object:UnlockHighlight() end
    function Object:GetFontString() return self._fs end
    function Object:SetFontString(fs) self._fs = fs end
    function Object:SetButtonState() end
    -- sliders / scroll frames
    function Object:SetMinMaxValues(a, b) self._min, self._max = a, b end
    function Object:GetMinMaxValues() return self._min or 0, self._max or 1 end
    function Object:SetValue(v) self._value = v; self:_fire("OnValueChanged", v, true) end
    function Object:GetValue() return self._value or 0 end
    function Object:SetValueStep(s) self._step = s end
    function Object:SetObeyStepOnDrag() end
    function Object:SetOrientation() end
    function Object:SetThumbTexture(t) self._thumb = t end
    function Object:SetScrollChild(c) self._scrollChild = c; c._scrollParent = self end
    function Object:GetScrollChild() return self._scrollChild end
    function Object:SetVerticalScroll(v) self._vscroll = v end
    function Object:GetVerticalScroll() return self._vscroll or 0 end
    function Object:GetVerticalScrollRange()
        local c = self._scrollChild
        if not c then return 0 end
        return math.max(0, (c._h or 0) - rectOf(self)[4])
    end
    function Object:UpdateScrollChildRect() end

    G.CreateFrame = function(kind, name, parent, template)
        local o = newObject(kind or "Frame", name, parent)
        if kind == "EditBox" then o._text = ""; o._enabled = true end
        if kind == "ScrollFrame" then o._clips = true end
        if kind == "Button" or kind == "CheckButton" then o._enabled = true end
        if template and template:find("BackdropTemplate") then
            function o:SetBackdrop(b) self._backdrop = b end
            function o:SetBackdropColor() end
            function o:SetBackdropBorderColor() end
        end
        return o
    end

    local root = newObject("Frame", "UIParent", nil)
    root._isRoot = true
    G.UIParent = root
    G.WorldFrame = root
    G.Minimap = G.CreateFrame("Frame", "Minimap", root)
    G.Minimap:SetSize(200, 200)
    G.Minimap:SetPoint("TOPRIGHT", root, "TOPRIGHT", -10, -10)
    G.GetScreenWidth = function() return 1920 end
    G.GetScreenHeight = function() return 1080 end
    G.GetPhysicalScreenSize = function() return 1920, 1080 end
    G.CreateColor = function(r, g, b, a) return { r = r, g = g, b = b, a = a or 1, GetRGBA = function(c) return c.r, c.g, c.b, c.a end } end
    G.GetCursorPosition = function() return W.cursorX or 0, W.cursorY or 0 end
    G.GetMouseFocus = function() return W.mouseFocus end
    G.UISpecialFrames = {}
    G.STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
    G.GameFontNormal = {}
    G.GameTooltip = G.CreateFrame("GameTooltip", "GameTooltip", root)
    do
        local tt = G.GameTooltip
        tt._lines = {}
        function tt:SetOwner(o, a) self._owner, self._anchor = o, a; self._lines = {} end
        function tt:ClearLines() self._lines = {} end
        function tt:AddLine(t) table.insert(self._lines, t) end
        function tt:AddDoubleLine(a, b) table.insert(self._lines, a .. " | " .. b) end
        function tt:SetText(t) self._lines = { t } end
        function tt:SetHyperlink(l) self._link = l end
        function tt:GetOwner() return self._owner end
        function tt:NumLines() return #self._lines end
        tt._shown = false
    end
    G.ItemRefTooltip = G.GameTooltip
    G.SetItemRef = function(link, text, button) W.itemRef = { link, text, button } end
    G.IsModifiedClick = function(what) return W.modified == (what or true) or W.modified == true end
    G.IsShiftKeyDown = function() return W.shift == true end
    G.IsControlKeyDown = function() return W.ctrl == true end
    G.IsAltKeyDown = function() return false end
    G.CopyToClipboard = nil

    ---------------------------------------------------------------------------
    --  Timers
    ---------------------------------------------------------------------------
    local function addTimer(delay, fn, iterations, handle)
        local t = { due = W.clock + math.max(delay or 0, 0), fn = fn, every = delay, left = iterations, handle = handle }
        table.insert(W.timers, t)
        return t
    end
    G.C_Timer = {
        After = function(d, fn) addTimer(d, fn) end,
        NewTimer = function(d, fn)
            local h = { cancelled = false }
            function h:Cancel() self.cancelled = true end
            function h:IsCancelled() return self.cancelled end
            addTimer(d, fn, 1, h)
            return h
        end,
        NewTicker = function(d, fn, n)
            local h = { cancelled = false }
            function h:Cancel() self.cancelled = true end
            function h:IsCancelled() return self.cancelled end
            addTimer(d, fn, n or math.huge, h)
            return h
        end,
    }
    function W.advance(dt)
        W.clock = W.clock + (dt or 0)
        for _ = 1, 10000 do
            local due
            for _, t in ipairs(W.timers) do
                if t.due <= W.clock and not (t.handle and t.handle.cancelled) and (not due or t.due < due.due) then due = t end
            end
            if not due then break end
            if due.left and due.left > 1 then
                due.left = due.left - 1
                due.due = due.due + math.max(due.every, 0.001)
            else
                for i, t in ipairs(W.timers) do if t == due then table.remove(W.timers, i); break end end
            end
            due.fn(due.handle)
        end
        for i = #W.timers, 1, -1 do
            local t = W.timers[i]
            if t.handle and t.handle.cancelled then table.remove(W.timers, i) end
        end
        -- One OnUpdate per advance for every visible frame.
        if dt and dt > 0 then
            local list = {}
            for i, f in ipairs(W.allFrames) do list[i] = f end
            for _, f in ipairs(list) do
                local fn = f._scripts.OnUpdate
                if fn and f:IsVisible() then fn(f, dt) end
            end
        end
    end

    ---------------------------------------------------------------------------
    --  Events
    ---------------------------------------------------------------------------
    function W.fire(event, ...)
        local list = W.events[event]
        if not list then return end
        local copy = {}
        for i, f in ipairs(list) do copy[i] = f end
        for _, f in ipairs(copy) do
            local fn = f._scripts.OnEvent
            if fn then fn(f, event, ...) end
        end
    end

    ---------------------------------------------------------------------------
    --  Game state and APIs
    ---------------------------------------------------------------------------
    W.player = { name = "Ayla Brightwind", realm = "Forever Realm One", class = "Druid", classFile = "DRUID",
        race = "Tauren", faction = "Horde", guid = "Player-1-00000001" }
    -- Forever (regional unique names): UnitName returns first name and surname.
    W.run = true
    G.RegionalUniqueNamesEnabled = function() return W.run end
    G.Constants = { CharacterNameSeparatorConsts = { CHARACTERNAME_SURNAME_SEPARATOR = " " },
        ChatFrameConstants = { MaxChatChannels = 20 } }
    local function nameParts(full)
        local first, last = full:match("^(%S+)%s+(.+)$")
        if first and W.run then return first, last end
        return full, nil
    end
    G.UnitName = function(u)
        if u == "player" then return nameParts(W.player.name) end
        local x = W.units and W.units[u]
        if x then
            if W.run then return nameParts(x.name) end
            return x.name, x.realm
        end
    end
    G.UnitNameUnmodified = G.UnitName
    G.UnitFullName = G.UnitName
    G.NameUtil = {
        GetUnmodifiedUnitFullName = function(u)
            local n, s = G.UnitNameUnmodified(u)
            if s then return n .. " " .. s end
            return n
        end,
    }
    G.IsResting = function() return W.resting == true end
    -- Key bindings and override bindings.
    W.bindings = { REPLY = { "R" }, REPLY2 = { "SHIFT-R" } }
    W.overrides = {}
    G.GetBindingKey = function(action) return unpack(W.bindings[action] or {}) end
    G.SetOverrideBinding = function(owner, priority, key, command)
        if W.combat then error("SetOverrideBinding: blocked in combat", 2) end
        W.overrides[key] = command
    end
    G.ClearOverrideBindings = function(owner)
        if W.combat then error("ClearOverrideBindings: blocked in combat", 2) end
        W.overrides = {}
    end
    G.UnitGUID = function(u) if u == "player" then return W.player.guid end local x = W.units and W.units[u]; return x and x.guid end
    G.UnitClass = function(u)
        if u == "player" then return W.player.class, W.player.classFile end
        local x = W.units and W.units[u]
        if x then return x.class, x.classFile end
    end
    G.UnitRace = function(u) local x = W.units and W.units[u]; if x then return x.race, x.raceFile end end
    G.UnitLevel = function(u) local x = W.units and W.units[u]; return x and x.level or 0 end
    G.UnitExists = function(u) return u == "player" or (W.units and W.units[u] ~= nil) end
    G.UnitIsPlayer = function(u) return u == "player" or (W.units and W.units[u] ~= nil and W.units[u].player ~= false) end
    G.UnitFactionGroup = function() return W.player.faction end
    G.GetRealmName = function() return W.player.realm end
    G.GetNormalizedRealmName = function() return (W.player.realm:gsub("[%s%-]", "")) end
    G.IsInGroup = function() return W.group ~= nil end
    G.IsInRaid = function() return false end
    G.GetNumGroupMembers = function() return W.group and #W.group or 0 end
    G.IsInInstance = function() return W.instance == true, W.instance and "party" or "none" end
    G.InCombatLockdown = function() return W.combat end
    G.Ambiguate = function(name, ctx)
        if type(name) ~= "string" then error("Ambiguate: string expected", 2) end
        local n, r = name:match("^(.-)%-(.+)$")
        if n and r and (r == G.GetNormalizedRealmName() or ctx == "short") then return n end
        return name
    end
    G.GetPlayerInfoByGUID = function(guid)
        local x = W.guids[guid]
        if x then return x.classLoc, x.classFile, x.raceLoc, x.raceFile, x.sex or 2, x.name, x.realm or "" end
    end
    G.GetCVar = function(k) return W.cvars[k] end
    G.GetCVarBool = function(k) return W.cvars[k] == "1" end
    G.SetCVar = function(k, v) W.cvars[k] = tostring(v) end
    G.PlaySound = function(id, channel) table.insert(W.sounds, { kit = id, channel = channel }) end
    G.PlaySoundFile = function(path, channel) table.insert(W.sounds, { file = path, channel = channel }); return true end
    G.FlashClientIcon = function() W.flashes = W.flashes + 1 end
    G.SOUNDKIT = { TELL_MESSAGE = 3081, IG_MAINMENU_OPTION_CHECKBOX_ON = 856, IG_MAINMENU_OPTION_CHECKBOX_OFF = 857,
        U_CHAT_SCROLL_BUTTON = 1115 }
    G.ReloadUI = function() W.reloads = W.reloads + 1 end
    G.C_AddOns = {
        IsAddOnLoaded = function(n) return W.loadedAddons[n] == true end,
        GetAddOnMetadata = function(n, k)
            if n ~= "Sotto" then return nil end
            for line in io.lines("Sotto.toc") do
                local key, value = line:match("^## ([%w%-]+):%s*(.-)%s*$")
                if key == k then return value end
            end
        end,
        DisableAddOn = function(n, who) W.disabledAddons[n] = who or true end,
        GetAddOnEnableState = function(n) return W.loadedAddons[n] and 2 or 0 end,
    }
    G.GetLocale = function() return "enUS" end
    G.Enum = {
        AddOnRestrictionType = { Combat = 0, Encounter = 1, ChallengeMode = 2, PvPMatch = 3, Map = 4, Chat = 5 },
        AddOnRestrictionState = { Inactive = 0, Activating = 1, Active = 2 },
        BattleNetFriendLevel = { Title = 1, Account = 2 },
    }
    G.RAID_CLASS_COLORS = {
        WARRIOR = { r = 0.78, g = 0.61, b = 0.43 }, PALADIN = { r = 0.96, g = 0.55, b = 0.73 },
        HUNTER = { r = 0.67, g = 0.83, b = 0.45 }, ROGUE = { r = 1, g = 0.96, b = 0.41 },
        PRIEST = { r = 1, g = 1, b = 1 }, SHAMAN = { r = 0, g = 0.44, b = 0.87 },
        MAGE = { r = 0.25, g = 0.78, b = 0.92 }, WARLOCK = { r = 0.53, g = 0.53, b = 0.93 },
        DRUID = { r = 1, g = 0.49, b = 0.04 },
    }
    G.C_ClassColor = { GetClassColor = function(f) return G.RAID_CLASS_COLORS[f] end }
    G.CLASS_ICON_TCOORDS = {
        WARRIOR = { 0, 0.25, 0, 0.25 }, MAGE = { 0.25, 0.49609375, 0, 0.25 }, ROGUE = { 0.49609375, 0.7421875, 0, 0.25 },
        DRUID = { 0.7421875, 0.98828125, 0, 0.25 }, HUNTER = { 0, 0.25, 0.25, 0.5 }, SHAMAN = { 0.25, 0.49609375, 0.25, 0.5 },
        PRIEST = { 0.49609375, 0.7421875, 0.25, 0.5 }, WARLOCK = { 0.7421875, 0.98828125, 0.25, 0.5 },
        PALADIN = { 0, 0.25, 0.5, 0.75 },
    }
    G.LOCALIZED_CLASS_NAMES_MALE = { WARRIOR = "Warrior", MAGE = "Mage", ROGUE = "Rogue", DRUID = "Druid",
        HUNTER = "Hunter", SHAMAN = "Shaman", PRIEST = "Priest", WARLOCK = "Warlock", PALADIN = "Paladin" }
    G.FRIENDS_BNET_NAME_COLOR = { r = 0.510, g = 0.773, b = 1 }
    G.C_Texture = { GetAtlasInfo = function(a) return W.atlases[a] end }
    G.ERR_CHAT_PLAYER_NOT_FOUND_S = "No player named '%s' is currently playing."
    G.CHAT_IGNORED = "%s is ignoring you."
    G.ERR_FRIEND_ONLINE_SS = "|Hplayer:%s|h[%s]|h has come online."
    G.ERR_FRIEND_OFFLINE_S = "%s has gone offline."
    G.CHAT_AFK_GET = "%s is Away From Keyboard: "
    G.CHAT_DND_GET = "%s does not wish to be disturbed: "
    G.NUM_CHAT_WINDOWS = 10
    G.SLASH_WHISPER1 = "/w"
    G.SlashCmdList = {}
    G.hash_SlashCmdList = {}

    -- friends, guild, Battle.net ------------------------------------------------
    G.C_FriendList = {
        GetNumFriends = function() return #W.friends end,
        GetFriendInfoByIndex = function(i) return W.friends[i] end,
        GetFriendInfo = function(name)
            for _, f in ipairs(W.friends) do if f.name == name then return f end end
        end,
        AddFriend = function(n) W.addedFriend = n end,
        AddIgnore = function(n) W.ignored = n; return true end,
        IsIgnored = function(n) return W.ignored == n end,
        ShowFriends = function() end,
    }
    G.IsInGuild = function() return #W.guild > 0 end
    G.GetNumGuildMembers = function() return #W.guild, #W.guild end
    G.GetGuildRosterInfo = function(i)
        local r = W.guild[i]
        if r then return r.name, r.rank or "", 0, r.level, r.class, r.zone, "", "", r.online, 0, r.classFile end
    end
    G.C_GuildInfo = { GuildRoster = function() W.rosterRequested = true end }
    G.C_PartyInfo = { InviteUnit = function(n) W.invited = n end }
    G.InviteUnit = function(n) W.invited = n end
    G.BNGetNumFriends = function() return #W.bnFriends end
    G.BNet_GetBNetIDAccount = function(name)
        for _, f in ipairs(W.bnFriends) do if f.accountName == name then return f.bnetAccountID end end
    end
    G.C_BattleNet = {
        GetFriendAccountInfo = function(i) return W.bnFriends[i] end,
        GetAccountInfoByID = function(id)
            for _, f in ipairs(W.bnFriends) do if f.bnetAccountID == id then return f end end
        end,
        SendWhisper = function(id, text) table.insert(W.bnSent, { id = id, text = text }) end,
        GetDefaultTitleWhisperTarget = function() return nil end,
    }

    -- chat ----------------------------------------------------------------------
    G.C_ChatInfo = {
        SendChatMessage = function(msg, chatType, lang, target)
            if W.lockdown then W.blocked = (W.blocked or 0) + 1; return end
            table.insert(W.sent, { msg = msg, chatType = chatType, target = target })
        end,
        InChatMessagingLockdown = function() return W.lockdown end,
        GetChatLineText = function(id) local l = W.chatLines[id]; return l and l.text end,
        GetChatLineSenderName = function(id) local l = W.chatLines[id]; return l and l.sender end,
        GetChatLineSenderGUID = function(id) local l = W.chatLines[id]; return l and l.guid end,
        IsChatLineCensored = function() return false end,
    }
    G.ChatTypeInfo = setmetatable({}, { __index = function() return { r = 1, g = 0.5, b = 1, sticky = 0 } end })

    -- Blizzard chat frame and its edit box, close to the forever branch code.
    local filters = {}
    local lastTell = {}
    W.filters = filters
    G.ChatFrameUtil = {}
    local CFU = G.ChatFrameUtil
    function CFU.AddMessageEventFilter(event, fn)
        filters[event] = filters[event] or {}
        for _, f in ipairs(filters[event]) do if f == fn then return end end
        table.insert(filters[event], fn)
    end
    function CFU.RemoveMessageEventFilter(event, fn)
        for i, f in ipairs(filters[event] or {}) do if f == fn then table.remove(filters[event], i); return end end
    end
    function CFU.ProcessMessageEventFilters(frame, event, ...)
        local args = pack(...)
        for _, fn in ipairs(filters[event] or {}) do
            if G.canaccessvalue(unpack(args, 1, args.n)) then
                local r = pack(fn(frame, event, unpack(args, 1, args.n)))
                if r[1] then return true end
                if r[2] ~= nil then for i = 2, r.n do args[i - 1] = r[i] end end
            end
        end
        return false, unpack(args, 1, args.n)
    end
    function CFU.SetLastTellTarget(t, ty) lastTell[1], lastTell[2] = t, ty end
    function CFU.GetLastTellTarget() return lastTell[1], lastTell[2] end
    function CFU.GetActiveWindow() return W.activeEditBox end
    function CFU.GetLastActiveWindow() return W.lastEditBox end

    G.ChatFrameEditBoxMixin = {}
    function G.ChatFrameEditBoxMixin.OnEscapePressed(eb) eb:ClearChat() end

    local chat1 = G.CreateFrame("Frame", "ChatFrame1", root)
    G.DEFAULT_CHAT_FRAME, G.SELECTED_CHAT_FRAME = chat1, chat1
    function chat1:AddMessage(text) table.insert(W.chatLog, text) end
    local eb = G.CreateFrame("EditBox", "ChatFrame1EditBox", chat1)
    chat1.editBox = eb
    eb._shown = false
    eb:SetAttribute("chatType", "SAY")
    eb:SetAttribute("stickyType", "SAY")
    function eb:GetChatType() return self:GetAttribute("chatType") end
    function eb:SetChatType(t) self:SetAttribute("chatType", t) end
    function eb:GetStickyType() return self:GetAttribute("stickyType") end
    function eb:SetStickyType(t) self:SetAttribute("stickyType", t) end
    function eb:GetTellTarget() return self:GetAttribute("tellTarget") end
    function eb:SetTellTarget(t) self:SetAttribute("tellTarget", t) end
    function eb:UpdateHeader() self._headers = (self._headers or 0) + 1 end
    function eb:ProcessChatType(msg, index, send)
        if index == "REPLY" then
            local t, ty = G.ChatFrameUtil.GetLastTellTarget()
            if t then
                self:SetChatType(ty)
                self:SetTellTarget(t)
                self:SetText(msg)
                self:UpdateHeader()
            end
            return true
        end
        return false
    end
    function eb:ClearChat()
        self:SetChatType(self:GetStickyType())
        self:SetText("")
        self:Hide()
        if W.activeEditBox == self then W.activeEditBox = nil end
        self:ClearFocus()
    end
    for i = 2, 10 do
        local cf = G.CreateFrame("Frame", "ChatFrame" .. i, root)
        cf._shown = false
        function cf:AddMessage() end
    end
    function CFU.ChooseBoxForSend() return eb end
    function CFU.ActivateChat(box)
        W.activeEditBox, W.lastEditBox = box, box
        box:Show()
        box:SetFocus()
        box:UpdateHeader()
    end
    function CFU.OpenChat(text, chatFrame)
        local box = CFU.ChooseBoxForSend(chatFrame)
        CFU.ActivateChat(box)
        if text then box:SetText(text) end
        box:UpdateHeader()
        return box
    end
    -- "/w Name " then ParseText(0): the edit box switches to WHISPER.
    function CFU.SendTellWithMessage(name, text)
        local box = CFU.ChooseBoxForSend()
        CFU.OpenChat("/w " .. name .. " " .. (text or ""))
        box:SetChatType("WHISPER")
        box:SetTellTarget(name)
        box:SetText(text or "")
        box:UpdateHeader()
    end
    function CFU.SendTell(name) CFU.SendTellWithMessage(name, "") end
    function CFU.SendBNetTell(kname)
        local box = CFU.ChooseBoxForSend()
        box:SetTellTarget(kname)
        box:SetChatType("BN_WHISPER")
        if box ~= CFU.GetActiveWindow() then CFU.OpenChat("") else box:UpdateHeader() end
    end
    function CFU.ReplyTell(chatFrame)
        local box = CFU.ChooseBoxForSend(chatFrame)
        local t, ty = CFU.GetLastTellTarget()
        if t then
            box:SetChatType(ty)
            box:SetTellTarget(t)
            box:UpdateHeader()
            if box ~= CFU.GetActiveWindow() then CFU.OpenChat("", chatFrame) end
        end
    end
    function CFU.ReplyTell2(chatFrame) CFU.ReplyTell(chatFrame) end
    function CFU.InsertLink(text)
        local active = CFU.GetActiveWindow()
        if active then active:Insert(text); return true end
        return false
    end

    -- Blizzard's chat frame receives a CHAT_MSG event before any addon frame.
    local function blizzardChat(event, ...)
        if event:sub(1, 9) ~= "CHAT_MSG_" then return end
        local args = pack(...)
        if args[6] == "GM" and event == "CHAT_MSG_WHISPER" then return end
        local discard = CFU.ProcessMessageEventFilters(chat1, event, unpack(args, 1, args.n))
        if discard then return end
        table.insert(W.chatLog, { event = event, text = args[1], sender = args[2] })
        if event == "CHAT_MSG_WHISPER" or event == "CHAT_MSG_BN_WHISPER" then
            CFU.SetLastTellTarget(args[2], event == "CHAT_MSG_WHISPER" and "WHISPER" or "BN_WHISPER")
            G.PlaySound(G.SOUNDKIT.TELL_MESSAGE)
        end
    end
    -- What the client does for a chat event: chat frames first, then addons.
    function W.chat(event, ...)
        blizzardChat(event, ...)
        W.fire(event, ...)
    end

    -- Handy builders for the 17 whisper arguments.
    W.lineID = 100
    function W.whisperArgs(text, sender, o)
        o = o or {}
        W.lineID = W.lineID + 1
        return text, sender, "", "", sender, o.flags or "", 0, 0, "", 0, o.lineID or W.lineID,
            o.guid or "", o.bnID or 0, false, false, o.letterbox or false, false
    end

    -- EllesmereUI stand-in (only when a test asks for it).
    function W.installEUI(o)
        o = o or {}
        local looks = {}
        local S = {
            apiVersion = 4,
            GetAccentColor = function() local c = o.accent or { 0, 0.81, 1 }; return c[1], c[2], c[3] end,
            GetPanelColor = function() local c = o.panel or { 0.08, 0.08, 0.08, 0.92 }; return c[1], c[2], c[3], c[4] end,
            GetFont = function() return o.font or "Interface\\AddOns\\EllesmereUI\\media\\fonts\\Expressway.TTF", o.flag or "" end,
            OnLooksChanged = function(fn) table.insert(looks, fn) end,
            IsEnabled = function() return true end,
        }
        W.eui = { S = S, looks = looks, options = o }
        G.EllesmereUI = {
            RegisterSkin = function(name, fn) W.eui.name, W.eui.apply = name, fn end,
        }
        return W.eui
    end
    function W.euiLogin() if W.eui and W.eui.apply then W.eui.apply(W.eui.S) end end
    function W.euiChange(o)
        for k, v in pairs(o) do W.eui.options[k] = v end
        for _, fn in ipairs(W.eui.looks) do fn() end
    end

    setmetatable(G, {
        __newindex = function(t, k, v) W.globalsWritten[k] = true; rawset(t, k, v) end,
    })
    return G, W
end

return F
