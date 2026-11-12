-------------------------------------------------------------------------------
--  Sotto: conversations and their messages.
--  Character conversations belong to the logged-in character
--  (SottoDB.chars[charKey].convs); Battle.net conversations are shared by all
--  characters (SottoDB.bn), keyed by BattleTag when it is readable, else by the
--  session's account id.
--
--  conv = { key, kind = "w"|"bn", name, tag, bnID, class, race, level, zone,
--           guid, online, char, last, unread, open, msgs = { msg... } }
--  msg  = { t = time, d = "i"|"o"|"s" (in, out, system), m = text, s = kind }
-------------------------------------------------------------------------------
local _, ns = ...
local S = {}
ns.Store = S

local MAX_MESSAGES = 400

-- Session-only tie-breaker: two messages in the same second still sort the
-- conversation touched last first. Not saved.
local touched = setmetatable({}, { __mode = "k" })
local touchSeq = 0
local function touch(conv)
    touchSeq = touchSeq + 1
    touched[conv] = touchSeq
end

local function charConvs()
    local db = ns.DB
    if not db then return nil end
    local ck = ns.CharKey()
    local bucket = db.chars[ck]
    if type(bucket) ~= "table" then bucket = {}; db.chars[ck] = bucket end
    if type(bucket.convs) ~= "table" then bucket.convs = {} end
    return bucket.convs
end

local function readable(v, kind)
    if ns.IsSecret(v) or type(v) ~= kind then return nil end
    if kind == "string" and v == "" then return nil end
    return v
end

local function newConv(key, kind, name)
    return { key = key, kind = kind, name = name, unread = 0, open = true, last = time(), msgs = {} }
end

function S.Get(key)
    if not key or not ns.DB then return nil end
    return charConvs()[key] or ns.DB.bn[key]
end

-- -> conv, isNew (nil for a name or id that cannot be used)
function S.Ensure(kind, name, extra)
    if not ns.DB then return nil end
    extra = extra or {}
    if kind == "bn" then
        local tag = readable(extra.tag, "string")
        local id = readable(extra.bnID, "number")
        if not tag and not id then return nil end
        local key = tag and ("bn:" .. tag:lower()) or ("bn:id:" .. id)
        local conv = ns.DB.bn[key]
        local isNew = conv == nil
        if isNew then
            conv = newConv(key, "bn", readable(name, "string") or tag)
            ns.DB.bn[key] = conv
        end
        if tag then conv.tag = tag end
        if id then conv.bnID = id end
        local n = readable(name, "string")
        if n then conv.name = n end
        if isNew then ns.Fire("CONV_ADDED", conv) end
        return conv, isNew
    end
    local key = ns.Names.Key(name)
    if not key then return nil end
    local convs = charConvs()
    local conv = convs[key]
    if conv then return conv, false end
    conv = newConv(key, "w", ns.Names.Display(name))
    convs[key] = conv
    ns.Fire("CONV_ADDED", conv)
    return conv, true
end

-- Messages stay in time order (a message recovered after a lockdown can be
-- older than the newest one).
function S.Add(conv, d, text, t, sys)
    local msg = { t = t or time(), d = d, m = text, s = sys }
    local msgs = conv.msgs
    local i = #msgs
    while i > 0 and msgs[i].t > msg.t do i = i - 1 end
    table.insert(msgs, i + 1, msg)
    while #msgs > MAX_MESSAGES do table.remove(msgs, 1) end
    -- The first message decides the recency of a new conversation (its
    -- creation time may be later, e.g. a whisper recovered after a lockdown).
    if #msgs == 1 or msg.t >= (conv.last or 0) then
        conv.last = msg.t
        touch(conv)
    end
    conv.open = true
    ns.Fire("MESSAGE_ADDED", conv, msg)
    ns.Fire("CONV_UPDATED", conv)
    return msg
end

function S.MarkUnread(conv, n)
    conv.unread = (conv.unread or 0) + (n or 1)
    ns.Fire("UNREAD_CHANGED", conv)
end

function S.MarkRead(conv)
    if (conv.unread or 0) > 0 then
        conv.unread = 0
        ns.Fire("UNREAD_CHANGED", conv)
    end
end

function S.List()
    local out = {}
    if not ns.DB then return out end
    for _, conv in pairs(charConvs()) do
        if conv.open then out[#out + 1] = conv end
    end
    for _, conv in pairs(ns.DB.bn) do
        if conv.open then out[#out + 1] = conv end
    end
    table.sort(out, function(a, b)
        if (a.last or 0) ~= (b.last or 0) then return (a.last or 0) > (b.last or 0) end
        local ta, tb = touched[a] or 0, touched[b] or 0
        if ta ~= tb then return ta > tb end
        return a.key < b.key
    end)
    return out
end

function S.Close(conv)
    conv.open = false
    local had = (conv.unread or 0) > 0
    conv.unread = 0
    ns.Fire("CONV_UPDATED", conv)
    if had then ns.Fire("UNREAD_CHANGED", conv) end
end

function S.Clear(conv)
    conv.msgs = {}
    ns.Fire("CONV_UPDATED", conv)
end

function S.UnreadTotal()
    local n = 0
    for _, conv in ipairs(S.List()) do n = n + (conv.unread or 0) end
    return n
end

-- days = 0: keep nothing (history only lasts until logout).
local function pruneBucket(bucket, cutoff)
    for key, conv in pairs(bucket) do
        local keep = {}
        for _, msg in ipairs(conv.msgs or {}) do
            if cutoff and msg.t >= cutoff then keep[#keep + 1] = msg end
        end
        conv.msgs = keep
        if #keep == 0 and (not conv.open or not cutoff or (conv.last or 0) < cutoff) then
            bucket[key] = nil
        end
    end
end

function S.Prune(days)
    if not ns.DB then return end
    local cutoff = (days and days > 0) and (time() - days * 86400) or nil
    for _, bucket in pairs(ns.DB.chars) do
        if type(bucket) == "table" and type(bucket.convs) == "table" then pruneBucket(bucket.convs, cutoff) end
    end
    pruneBucket(ns.DB.bn, cutoff)
    ns.Fire("CONV_UPDATED")
end

ns.On("PLAYER_LOGIN", function()
    S.Prune(ns.Get("keepDays"))
end)

ns.On("PLAYER_LOGOUT", function()
    if ns.Get("keepDays") == 0 then S.Prune(0) end
end)

ns.Listen("SETTING_CHANGED", function(key, value)
    if key == "keepDays" and type(value) == "number" and value > 0 then S.Prune(value) end
end)
