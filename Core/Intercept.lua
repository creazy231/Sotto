-------------------------------------------------------------------------------
--  Sotto: the reply keys and "Whisper" in player menus. Sotto never writes to
--  Blizzard's chat edit box or its last-tell list: on this client a box closed
--  or refocused from addon code leaves ACTIVE_CHAT_EDIT_BOX tainted, and
--  Blizzard's chat code then errors on the secret names of Battle.net
--  whispers and chat lockdown.
--
--  Instead, while "Use Sotto to whisper" is on and the player is outside
--  instances (inside, whispers are secret: only Blizzard's chat can show and
--  answer them):
--  - the player's own keys for REPLY and REPLY2 are bound to Sotto's bindings
--    (override bindings, set out of combat);
--  - the Whisper entry of player menus opens Sotto. Menus take changes from
--    addons through Menu.ModifyMenu; Sotto swaps only that entry's responder,
--    so Blizzard's chat box never opens, and every other entry stays
--    Blizzard's (the menu system keeps an addon's responder from tainting its
--    neighbours). In chat lockdown, and for names the client keeps secret,
--    the entry is left alone.
--
--  /w stays with Blizzard's chat box; the whisper then opens its conversation
--  in Sotto (Engine: OUTGOING). A typed /r would use Blizzard's reply target,
--  which goes stale because Sotto hides whispers from the chat window; a
--  read-only post-hook prints a notice in that case.
--
--  In WoW Forever's gamepad interface (ns.Gamepad) all of it is Blizzard's: the
--  keys, the Whisper entry and /r answer in the game's own chat, which is made
--  for the controller.
-------------------------------------------------------------------------------
local _, ns = ...
local I = {}
ns.Intercept = I

local L = ns.L
local owner = CreateFrame("Frame")
local applied = {}
local MAP = { REPLY = "SOTTO_REPLY", REPLY2 = "SOTTO_REPLY_SENT" }

-- The setting is on, the player is outside instances and not in the gamepad
-- interface.
local function intercepting()
    if not ns.DB or not ns.Get("intercept") or ns.Gamepad() then return false end
    return not (IsInInstance and IsInInstance())
end

local function wanted()
    local out = {}
    if not intercepting() then return out end
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
    if InCombatLockdown() or ns.InLockdown() or ns.Gamepad() then return end
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
    I.HookMenus()
    I.Apply()
end

-------------------------------------------------------------------------------
--  "Whisper" in player menus opens Sotto
-------------------------------------------------------------------------------
local function readable(v, kind)
    if ns.IsSecret(v) or type(v) ~= kind then return nil end
    return v
end

-- Who the menu's Whisper entry would whisper, as Blizzard works it out
-- (UnitPopupWhisperButtonMixin:OnClick); nil when Sotto cannot tell.
local function menuTarget(cd)
    if type(cd) ~= "table" then return nil end
    -- A menu opened from a Battle.net name link (chat, EllesmereUI's friends
    -- list) gets the account id as text: Blizzard splits it out of the link.
    local rawID = cd.bnetIDAccount
    local bnID = not ns.IsSecret(rawID) and tonumber(rawID) or nil
    local isBN = bnID ~= nil
    local loc = cd.playerLocation
    if not isBN and type(loc) == "table" and type(loc.IsBattleNetGUID) == "function" then
        local ok, v = pcall(loc.IsBattleNetGUID, loc)
        isBN = ok and not ns.IsSecret(v) and v == true
    end
    local name = readable(cd.name, "string")
    if isBN then
        local info = type(cd.accountInfo) == "table" and cd.accountInfo or nil
        bnID = bnID or (info and readable(info.bnetAccountID, "number"))
        if not bnID and name and BNet_GetBNetIDAccount then
            local ok, id = pcall(BNet_GetBNetIDAccount, name)
            bnID = ok and readable(id, "number") or nil
        end
        if not bnID then return nil end
        local char = ns.Contacts.TitleTarget(bnID)
        if char then
            return ns.Names.Key(char) and { name = char } or nil
        end
        return { bn = bnID, name = name }
    end
    local full
    local util = UnitPopupSharedUtil
    if util and util.GetFullPlayerName then
        local ok, v = pcall(util.GetFullPlayerName, cd)
        if ok then full = readable(v, "string") end
    end
    full = full or name
    if not ns.Names.Key(full) then return nil end
    local guid = readable(cd.guid, "string")
    local unit = readable(cd.unit, "string")
    if not guid and unit then guid = readable(UnitGUID(unit), "string") end
    -- A name clicked in chat: the line's GUID, if that line is theirs.
    local line = readable(cd.lineID, "number")
    if not guid and line and C_ChatInfo and C_ChatInfo.GetChatLineSenderGUID then
        local ok, sender, g = pcall(function()
            return C_ChatInfo.GetChatLineSenderName(line), C_ChatInfo.GetChatLineSenderGUID(line)
        end)
        if ok and ns.Names.Key(sender) == ns.Names.Key(full) then guid = readable(g, "string") end
    end
    return { name = full, guid = guid }
end

local function openFor(target)
    local conv
    if target.bn then
        conv = ns.Engine.BNConversation(target.bn, target.name)
    else
        conv = ns.Store.Ensure("w", target.name)
        if conv and target.guid then ns.Contacts.Learn(conv, target.guid) end
    end
    if not conv then return end
    ns.UI.ClosePrompt()
    ns.UI.Open(conv, { focus = true })
end

local function isWhisper(desc)
    local text = MenuUtil.GetElementText(desc)
    return not ns.IsSecret(text) and text == WHISPER
end

local function findWhisper(desc)
    for _, child in desc:EnumerateElementDescriptions() do
        if isWhisper(child) then return child end
        local found = findWhisper(child)
        if found then return found end
    end
end

local function onMenu(_, root, contextData)
    if not intercepting() or ns.InLockdown() then return end
    local item = findWhisper(root)
    if not item then return end
    local target = menuTarget(contextData)
    if not target then return end
    item:SetResponder(function() openFor(target) end)
end

-- The forever branch's menus with a Whisper entry, should Blizzard's list of
-- unit menus ever move.
local WHISPER_MENUS = { "PLAYER", "PARTY", "RAID_PLAYER", "FRIEND", "BN_FRIEND", "BN_FRIEND_OFFLINE", "GUILD",
    "CHAT_ROSTER", "COMMUNITIES_WOW_MEMBER", "COMMUNITIES_GUILD_MEMBER", "RECENT_ALLY" }

function I.HookMenus()
    if not (Menu and Menu.ModifyMenu and MenuUtil and MenuUtil.GetElementText) then return end
    local tags = {}
    if type(UnitPopupMenus) == "table" then
        for which in pairs(UnitPopupMenus) do
            if type(which) == "string" then tags[#tags + 1] = which end
        end
    end
    if #tags == 0 then tags = WHISPER_MENUS end
    for _, which in ipairs(tags) do Menu.ModifyMenu("MENU_UNIT_" .. which, onMenu) end
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
ns.Listen("GAMEPAD_CHANGED", function() I.Apply() end)
