-------------------------------------------------------------------------------
--  Sotto: the chat engine.
--
--  Order of a whisper on this client (Blizzard_ChatFrameBase, forever branch):
--  the chat frames see the event first and run message filters (only when
--  every argument is readable), then addon frames get it. So:
--    * E.Filter decides alone whether the chat window hides a whisper: only
--      readable whispers Sotto will show, and only with "hideInChat" on;
--    * the event handler then stores it, alerts, and asks the UI to open.
--  A whisper Blizzard hid for us never reaches its own SetLastTellTarget,
--  TELL_MESSAGE sound or FlashClientIcon; Sotto does the sound and the flash
--  itself (and the reply target, see Intercept.lua).
--
--  Chat lockdown (12.x): text and sender arrive secret. Those whispers stay in
--  the chat window; their lineIDs are queued and rebuilt with
--  C_ChatInfo.GetChatLine* once the lockdown ends.
-------------------------------------------------------------------------------
local _, ns = ...
local E = {}
ns.Engine = E

local L = ns.L

local CHIME = "Interface\\AddOns\\Sotto\\Media\\Sounds\\chime.ogg"
local SEND_LIMIT = 255
local MAX_QUEUE = 200
local SOUND_COOLDOWN = 2

local lastInKey, lastOutKey
local queue = {}
local queueTicker
local seenLines, seenOrder = {}, {}
local locked = false
local lastSound = -math.huge

local function readable(v, kind)
    if ns.IsSecret(v) or type(v) ~= kind then return nil end
    if kind == "string" and v == "" then return nil end
    return v
end

-- true when this lineID was handled already (keeps the last 500)
local function seen(lineID)
    if ns.IsSecret(lineID) or type(lineID) ~= "number" or lineID <= 0 then return false end
    if seenLines[lineID] then return true end
    seenLines[lineID] = true
    seenOrder[#seenOrder + 1] = lineID
    if #seenOrder > 500 then seenLines[table.remove(seenOrder, 1)] = nil end
    return false
end

-------------------------------------------------------------------------------
--  Rules
-------------------------------------------------------------------------------
function E.ShouldOpen()
    local mode = ns.Get("openOn")
    if mode == "always" then return true end
    if mode == "never" then return false end
    return not InCombatLockdown()
end

local function alert(conv)
    if FlashClientIcon then FlashClientIcon() end
    local mode = ns.Get("sound")
    if mode == "none" then return end
    if ns.UI and ns.UI.Typing and ns.UI.Typing(conv) then return end
    local now = GetTime()
    if now - lastSound < SOUND_COOLDOWN then return end
    lastSound = now
    if mode == "game" then
        PlaySound(SOUNDKIT.TELL_MESSAGE, "Master")
    else
        PlaySoundFile(CHIME, "Master")
    end
end

local function isActive(conv)
    return ns.UI and ns.UI.IsShown and ns.UI.IsShown() and ns.UI.Active and ns.UI.Active() == conv
end

-------------------------------------------------------------------------------
--  System lines ("No player named ...", "... is ignoring you.", online/offline)
-------------------------------------------------------------------------------
local function toPattern(fmt)
    if type(fmt) ~= "string" then return nil end
    local p = fmt:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
    p = p:gsub("%%%%s", "(.+)")
    return "^" .. p .. "$"
end

local systemPatterns
local function systemMatch(text)
    if ns.IsSecret(text) or type(text) ~= "string" then return nil end
    if not systemPatterns then
        systemPatterns = {}
        for _, row in ipairs({
            { ERR_CHAT_PLAYER_NOT_FOUND_S, "notfound" }, { CHAT_IGNORED, "ignored" },
            { ERR_FRIEND_ONLINE_SS, "online" }, { ERR_FRIEND_OFFLINE_S, "offline" },
        }) do
            local p = toPattern(row[1])
            if p then systemPatterns[#systemPatterns + 1] = { p, row[2] } end
        end
    end
    for _, s in ipairs(systemPatterns) do
        local name = text:match(s[1])
        if name then
            local conv = ns.Store.Get(ns.Names.Key(name))
            if conv then return conv, s[2] end
            return nil
        end
    end
end

-------------------------------------------------------------------------------
--  Filter (runs inside Blizzard's chat frames, before our handlers)
-------------------------------------------------------------------------------
function E.Filter(frame, event, ...)
    if not ns.DB or not ns.Get("hideInChat") then return false end
    if ns.IsSecret(...) then return false end
    if event == "CHAT_MSG_SYSTEM" then
        local _, kind = systemMatch((...))
        return kind == "notfound" or kind == "ignored"
    end
    local text, who, _, _, _, flags, _, _, _, _, _, _, bnID, _, _, letterbox = ...
    if letterbox then return false end
    if event == "CHAT_MSG_AFK" or event == "CHAT_MSG_DND" then
        return ns.Store.Get(ns.Names.Key(who)) ~= nil
    end
    if type(text) ~= "string" then return false end
    if event == "CHAT_MSG_BN_WHISPER" or event == "CHAT_MSG_BN_WHISPER_INFORM" then
        return type(bnID) == "number" and bnID > 0
    end
    if flags == "GM" then return false end
    return ns.Names.Key(who) ~= nil
end

-------------------------------------------------------------------------------
--  Whispers
-------------------------------------------------------------------------------
local function bnConversation(bnID, who)
    local tag, name
    local info = C_BattleNet and C_BattleNet.GetAccountInfoByID and C_BattleNet.GetAccountInfoByID(bnID)
    if type(info) == "table" then
        tag = readable(info.battleTag, "string")
        name = readable(info.accountName, "string")
    end
    return ns.Store.Ensure("bn", readable(who, "string") or name, { tag = tag, bnID = bnID })
end

local function enqueue(event, ...)
    local n = select("#", ...)
    local entry = { event = event, t = time(), n = n, args = {} }
    for i = 1, n do
        local v = select(i, ...)
        if not ns.IsSecret(v) then entry.args[i] = v end
    end
    if type(entry.args[11]) ~= "number" then return end -- no lineID, nothing to rebuild from
    if #queue >= MAX_QUEUE then table.remove(queue, 1) end
    queue[#queue + 1] = entry
    if not queueTicker then
        queueTicker = C_Timer.NewTicker(2, function() E.Recover() end)
    end
end

-- The shared core. t: message time; recovered: rebuilt after a lockdown.
local function handle(event, t, recovered, ...)
    local text, who, _, _, _, flags, _, _, _, _, lineID, guid, bnID, _, _, letterbox = ...
    local bn = event == "CHAT_MSG_BN_WHISPER" or event == "CHAT_MSG_BN_WHISPER_INFORM"
    local out = event == "CHAT_MSG_WHISPER_INFORM" or event == "CHAT_MSG_BN_WHISPER_INFORM"

    if not ns.IsSecret(letterbox) and letterbox then return end
    if not bn and not ns.IsSecret(flags) and flags == "GM" then return end

    local usable
    if bn then
        usable = not ns.IsSecret(text, bnID) and type(text) == "string" and type(bnID) == "number" and bnID > 0
    else
        usable = not ns.IsSecret(text, who) and type(text) == "string" and type(who) == "string"
    end
    if not usable then
        if not recovered and ns.InLockdown() then enqueue(event, ...) end
        return
    end
    if seen(lineID) then return end

    local hadSecrets = ns.IsSecret(...)
    if ns.IsSecret(guid) then guid = nil end

    local conv, isNew
    if bn then
        conv, isNew = bnConversation(bnID, who)
    else
        conv, isNew = ns.Store.Ensure("w", who)
        if conv then ns.Contacts.Learn(conv, guid) end
    end
    if not conv then return end
    conv.online = true

    if out then
        ns.Store.Add(conv, "o", text, t)
        ns.Store.MarkRead(conv)
        lastOutKey = conv.key
        ns.Fire("OUTGOING", conv)
    else
        local msg = ns.Store.Add(conv, "i", text, t)
        lastInKey = conv.key
        if not isActive(conv) then ns.Store.MarkUnread(conv) end
        if ns.Get("hideInChat") and not hadSecrets then alert(conv) end
        ns.Fire("INCOMING", conv, msg, E.ShouldOpen(), recovered)
    end
    if isNew then ns.Contacts.Refresh(conv) end
end

local function onWhisper(event, ...)
    handle(event, time(), false, ...)
end

local AWAY_TEXT = { CHAT_MSG_AFK = "%s is away: %s", CHAT_MSG_DND = "%s does not want to be disturbed: %s" }

local function onAway(event, ...)
    if ns.IsSecret(...) then return end
    local text, who = ...
    local conv = ns.Store.Get(ns.Names.Key(who))
    if not conv or type(text) ~= "string" then return end
    local kind = event == "CHAT_MSG_AFK" and "afk" or "dnd"
    local line = L[AWAY_TEXT[event]]:format(ns.Names.Short(conv.name), text)
    -- One auto-reply per minute is enough: it comes back for every message.
    local last = conv.msgs[#conv.msgs]
    if last and last.s == kind and last.m == line and time() - last.t < 60 then return end
    ns.Store.Add(conv, "s", line, time(), kind)
end

local function onSystem(_, text)
    local conv, kind = systemMatch(text)
    if not conv then return end
    if kind == "notfound" or kind == "ignored" then
        conv.online = kind == "ignored" and conv.online or false
        ns.Store.Add(conv, "s", text, time(), kind)
    elseif kind == "online" or kind == "offline" then
        conv.online = kind == "online"
        ns.Fire("CONTACT_UPDATED", conv)
    end
end

local function onToast(_, ...)
    if ns.IsSecret(...) then return end
    local process = ...
    local bnID = select(13, ...)
    if (process ~= "FRIEND_ONLINE" and process ~= "FRIEND_OFFLINE") or type(bnID) ~= "number" then return end
    for _, conv in pairs(ns.DB and ns.DB.bn or {}) do
        if conv.bnID == bnID then
            conv.online = process == "FRIEND_ONLINE"
            ns.Fire("CONTACT_UPDATED", conv)
        end
    end
end

-------------------------------------------------------------------------------
--  Lockdown
-------------------------------------------------------------------------------
local function lineCall(fn, lineID)
    if not fn or type(lineID) ~= "number" then return nil end
    local ok, v = pcall(fn, lineID)
    if not ok or ns.IsSecret(v) or type(v) ~= "string" or v == "" then return nil end
    return v
end

function E.Recover()
    if ns.InLockdown() then return end
    local pending = queue
    queue = {}
    if queueTicker then queueTicker:Cancel(); queueTicker = nil end
    local info = C_ChatInfo or {}
    for _, e in ipairs(pending) do
        local a = e.args
        local lineID = a[11]
        a[1] = a[1] or lineCall(info.GetChatLineText, lineID)
        a[2] = a[2] or lineCall(info.GetChatLineSenderName, lineID)
        a[12] = a[12] or lineCall(info.GetChatLineSenderGUID, lineID)
        ns.Safe(handle, e.event, e.t, true, unpack(a, 1, e.n))
    end
end

local function checkLock()
    local now = ns.InLockdown()
    if now ~= locked then
        locked = now
        ns.Fire("LOCKDOWN_CHANGED", now)
    end
    if not now and #queue > 0 then C_Timer.After(0.2, E.Recover) end
end

-------------------------------------------------------------------------------
--  Sending
-------------------------------------------------------------------------------
local function sendChunk(conv, chunk)
    if conv.kind == "bn" then
        if not conv.bnID then return end
        local f = (C_BattleNet and C_BattleNet.SendWhisper) or BNSendWhisper
        if f then f(conv.bnID, chunk) end
        return
    end
    local f = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
    f(chunk, "WHISPER", nil, conv.name)
end

-- -> true when sending started; false in lockdown, for blank text or an
-- unreachable Battle.net friend.
function E.Send(conv, text)
    if not conv or ns.InLockdown() then return false end
    local chunks = ns.Format.Split(text, SEND_LIMIT)
    if #chunks == 0 then return false end
    if conv.kind == "bn" then
        ns.Contacts.ResolveBN(conv)
        if not conv.bnID then return false end
    end
    -- Two right away, the rest paced so a long burst stays under the throttle.
    for i, chunk in ipairs(chunks) do
        if i <= 2 then
            sendChunk(conv, chunk)
        else
            C_Timer.After(0.25 * (i - 2), function()
                if not ns.InLockdown() then sendChunk(conv, chunk) end
            end)
        end
    end
    return true
end

-------------------------------------------------------------------------------
--  Queries
-------------------------------------------------------------------------------
-- After a reload the session's last targets are gone: fall back to the newest
-- message on record in that direction.
local function newest(dir)
    local best, bestT
    for _, conv in ipairs(ns.Store.List()) do
        for i = #conv.msgs, 1, -1 do
            local m = conv.msgs[i]
            if m.d == dir then
                if not bestT or m.t > bestT then best, bestT = conv, m.t end
                break
            end
        end
    end
    return best
end

function E.LastIncoming() return (lastInKey and ns.Store.Get(lastInKey)) or newest("i") end
function E.LastOutgoing() return (lastOutKey and ns.Store.Get(lastOutKey)) or newest("o") end
function E.QueueSize() return #queue end
function E.Locked() return locked end

-------------------------------------------------------------------------------
--  Wiring
-------------------------------------------------------------------------------
for _, ev in ipairs({ "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM", "CHAT_MSG_BN_WHISPER",
    "CHAT_MSG_BN_WHISPER_INFORM" }) do
    ns.On(ev, onWhisper)
end
ns.On("CHAT_MSG_AFK", onAway)
ns.On("CHAT_MSG_DND", onAway)
ns.On("CHAT_MSG_SYSTEM", onSystem)
ns.On("CHAT_MSG_BN_INLINE_TOAST_ALERT", onToast)
for _, ev in ipairs({ "ADDON_RESTRICTION_STATE_CHANGED", "ENCOUNTER_START", "ENCOUNTER_END",
    "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA",
    "CHALLENGE_MODE_START", "CHALLENGE_MODE_COMPLETED" }) do
    ns.On(ev, checkLock)
end

local addFilter = (ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter) or ChatFrame_AddMessageEventFilter
if addFilter then
    for _, ev in ipairs({ "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM", "CHAT_MSG_BN_WHISPER",
        "CHAT_MSG_BN_WHISPER_INFORM", "CHAT_MSG_AFK", "CHAT_MSG_DND", "CHAT_MSG_SYSTEM" }) do
        addFilter(ev, E.Filter)
    end
end
