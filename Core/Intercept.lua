-------------------------------------------------------------------------------
--  Sotto: the reply keys. Sotto never writes to Blizzard's chat edit box or
--  its last-tell list: on this client a box closed or refocused from addon
--  code leaves ACTIVE_CHAT_EDIT_BOX tainted, and Blizzard's chat code then
--  errors on the secret names of Battle.net whispers and chat lockdown.
--
--  Instead, while "Use Sotto for replies" is on, the player's own keys for
--  REPLY and REPLY2 are bound to Sotto's bindings (override bindings, set out
--  of combat). Inside instances they stay with Blizzard: there whispers are
--  secret, only Blizzard's chat can show and answer them.
--
--  /w and "Whisper" in menus stay with Blizzard's chat box; the whisper then
--  opens its conversation in Sotto (Engine: OUTGOING). A typed /r would use
--  Blizzard's reply target, which goes stale because Sotto hides whispers
--  from the chat window; a read-only post-hook prints a notice in that case.
-------------------------------------------------------------------------------
local _, ns = ...
local I = {}
ns.Intercept = I

local L = ns.L
local owner = CreateFrame("Frame")
local applied = {}
local MAP = { REPLY = "SOTTO_REPLY", REPLY2 = "SOTTO_REPLY_SENT" }

local function wanted()
    local out = {}
    if not ns.DB or not ns.Get("intercept") then return out end
    if IsInInstance and IsInInstance() then return out end
    for action, command in pairs(MAP) do
        for _, key in ipairs({ GetBindingKey(action) }) do
            if type(key) == "string" and key ~= "" then out[key] = command end
        end
    end
    return out
end

local function same(a, b)
    for k, v in pairs(a) do if b[k] ~= v then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end

-- Brings the override bindings in line with the setting, the instance and
-- the player's key bindings. In combat it waits for PLAYER_REGEN_ENABLED.
function I.Apply()
    local want = wanted()
    if same(want, applied) then return end
    if InCombatLockdown() then return end
    ClearOverrideBindings(owner)
    for key, command in pairs(want) do SetOverrideBinding(owner, false, key, command) end
    applied = want
end

-------------------------------------------------------------------------------
--  Typed /r: tell the player when it would answer someone else
-------------------------------------------------------------------------------
local lastNotice = -math.huge

local function samePerson(conv, target)
    if conv.kind == "bn" then
        local id = BNet_GetBNetIDAccount and BNet_GetBNetIDAccount(target)
        return not ns.IsSecret(id) and id ~= nil and id == conv.bnID
    end
    return ns.Names.Key(target) == conv.key
end

local function onProcessChatType(_, _, index)
    if index ~= "REPLY" or not ns.DB then return end
    if InCombatLockdown() or ns.InLockdown() then return end
    local now = GetTime()
    if now - lastNotice < 1 then return end
    local mine = ns.Engine.LastIncoming()
    if not mine then return end
    local target = ChatFrameUtil and ChatFrameUtil.GetLastTellTarget and ChatFrameUtil.GetLastTellTarget()
    if ns.IsSecret(target) then return end
    if type(target) == "string" and target ~= "" and samePerson(mine, target) then return end
    lastNotice = now
    local who = ns.Contacts.Name(mine)
    if type(target) == "string" and target ~= "" then
        ns.Print(string.format(L["/r answers %s, but your last whisper came from %s. Your reply key answers in Sotto."],
            ns.Names.Display(target), who))
    else
        ns.Print(string.format(L["/r has no one to answer, your last whisper came from %s. Your reply key answers in Sotto."], who))
    end
end

function I.Init()
    for i = 1, (NUM_CHAT_WINDOWS or 10) do
        local box = _G["ChatFrame" .. i .. "EditBox"]
        if box and type(box.ProcessChatType) == "function" then
            hooksecurefunc(box, "ProcessChatType", onProcessChatType)
        end
    end
    I.Apply()
end

-------------------------------------------------------------------------------
--  Wiring
-------------------------------------------------------------------------------
ns.On("PLAYER_LOGIN", function() I.Init() end)
for _, ev in ipairs({ "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "UPDATE_BINDINGS", "PLAYER_REGEN_ENABLED" }) do
    ns.On(ev, function() I.Apply() end)
end
ns.Listen("SETTING_CHANGED", function(key)
    if key == "intercept" then I.Apply() end
end)
