-------------------------------------------------------------------------------
--  Sotto: who a conversation partner is. Class and race come from the
--  whisper's GUID; level, zone and online state from the friends list, the
--  guild roster, the group, target and mouseover, and Battle.net game account
--  info. Never /who. Every value is checked for secrecy before it is kept.
-------------------------------------------------------------------------------
local _, ns = ...
local C = {}
ns.Contacts = C

local L = ns.L

local function readable(v, kind)
    if ns.IsSecret(v) or type(v) ~= kind then return nil end
    if kind == "string" and v == "" then return nil end
    if kind == "number" and v <= 0 then return nil end
    return v
end

-- Localized class name -> class file ("Warrior" -> "WARRIOR").
local classFiles
local function classFile(localized)
    if not localized then return nil end
    if not classFiles then
        classFiles = {}
        for _, t in ipairs({ LOCALIZED_CLASS_NAMES_MALE or {}, LOCALIZED_CLASS_NAMES_FEMALE or {} }) do
            for file, name in pairs(t) do classFiles[name] = file end
        end
    end
    return classFiles[localized]
end

local function className(file)
    if not file then return nil end
    local t = LOCALIZED_CLASS_NAMES_MALE
    return (t and t[file]) or (file:sub(1, 1) .. file:sub(2):lower())
end

local function changed(conv)
    ns.Fire("CONTACT_UPDATED", conv)
end

-------------------------------------------------------------------------------
--  Sources
-------------------------------------------------------------------------------
function C.Learn(conv, guid)
    guid = readable(guid, "string")
    if not conv or not guid or not guid:find("^Player%-") then return end
    local ok, _, file, race = pcall(GetPlayerInfoByGUID, guid)
    if not ok then return end
    conv.guid = guid
    file, race = readable(file, "string"), readable(race, "string")
    if file then conv.class = file end
    if race then conv.race = race end
    changed(conv)
end

local function fromFriendInfo(conv, info)
    if type(info) ~= "table" then return false end
    local level = readable(info.level, "number")
    local file = classFile(readable(info.className, "string"))
    local area = readable(info.area, "string")
    local connected = info.connected
    if ns.IsSecret(connected) then connected = nil end
    if level then conv.level = level end
    if file then conv.class = file end
    if connected ~= nil then conv.online = connected and true or false end
    if connected and area then conv.zone = area end
    return true
end

local guildIndex, guildDirty = {}, true
local function buildGuildIndex()
    guildIndex, guildDirty = {}, false
    if not (IsInGuild and IsInGuild()) then return end
    local n = GetNumGuildMembers() or 0
    for i = 1, n do
        local name, _, _, level, class, zone, _, _, online, _, file = GetGuildRosterInfo(i)
        local key = ns.Names.Key(name)
        if key then
            guildIndex[key] = {
                level = readable(level, "number"), class = readable(file, "string") or classFile(readable(class, "string")),
                zone = readable(zone, "string"), online = (not ns.IsSecret(online)) and online or nil,
            }
        end
    end
end

local function fromUnit(conv, unit)
    local level = readable(UnitLevel(unit), "number")
    local _, file = UnitClass(unit)
    local race = UnitRace(unit)
    file, race = readable(file, "string"), readable(race, "string")
    if level then conv.level = level end
    if file then conv.class = file end
    if race then conv.race = race end
    local guid = readable(UnitGUID(unit), "string")
    if guid and guid:find("^Player%-") then conv.guid = guid end
    conv.online = true
end

local function unitKey(unit)
    if not UnitExists(unit) or not UnitIsPlayer(unit) then return nil end
    local name, realm = UnitName(unit)
    if ns.IsSecret(name, realm) or type(name) ~= "string" then return nil end
    if type(realm) == "string" and realm ~= "" then name = name .. "-" .. realm end
    return ns.Names.Key(name)
end

local function refreshCharacter(conv)
    if C_FriendList and C_FriendList.GetFriendInfo and conv.name then
        local ok, info = pcall(C_FriendList.GetFriendInfo, conv.name)
        if ok then fromFriendInfo(conv, info) end
    end
    if guildDirty then buildGuildIndex() end
    local g = guildIndex[conv.key]
    if g then
        if g.level then conv.level = g.level end
        if g.class then conv.class = g.class end
        if g.online ~= nil then conv.online = g.online and true or false end
        if g.online and g.zone then conv.zone = g.zone end
    end
    local n = GetNumGroupMembers and GetNumGroupMembers() or 0
    if n > 0 then
        local prefix = (IsInRaid and IsInRaid()) and "raid" or "party"
        for i = 1, n do
            local unit = prefix .. i
            if unitKey(unit) == conv.key then fromUnit(conv, unit) break end
        end
    end
end

-- Battle.net: session id first, then the BattleTag (ids change per session).
function C.ResolveBN(conv)
    if not (C_BattleNet and C_BattleNet.GetAccountInfoByID) then return nil end
    local id = readable(conv.bnID, "number")
    local info = id and C_BattleNet.GetAccountInfoByID(id)
    if type(info) == "table" and conv.tag and readable(info.battleTag, "string") ~= conv.tag then info = nil end
    if type(info) ~= "table" and conv.tag and C_BattleNet.GetFriendAccountInfo then
        local count = (BNGetNumFriends and BNGetNumFriends()) or 0
        for i = 1, count do
            local f = C_BattleNet.GetFriendAccountInfo(i)
            if type(f) == "table" and readable(f.battleTag, "string") == conv.tag then
                info = f
                conv.bnID = readable(f.bnetAccountID, "number")
                break
            end
        end
    end
    if type(info) ~= "table" then return nil end
    return info
end

local function refreshBN(conv)
    local info = C.ResolveBN(conv)
    if not info then return end
    local game = type(info.gameAccountInfo) == "table" and info.gameAccountInfo or {}
    local online = game.isOnline
    if ns.IsSecret(online) then online = nil end
    if online ~= nil then conv.online = online and true or false end
    local client = readable(game.clientProgram, "string")
    conv.client = client
    if online and client == "WoW" then
        conv.char = readable(game.characterName, "string")
        conv.level = readable(game.characterLevel, "number")
        conv.zone = readable(game.areaName, "string")
        conv.class = classFile(readable(game.className, "string")) or conv.class
        conv.race = readable(game.raceName, "string") or conv.race
    else
        conv.char, conv.zone = nil, nil
    end
end

function C.Refresh(conv)
    if not conv then return end
    if conv.kind == "bn" then refreshBN(conv) else refreshCharacter(conv) end
    changed(conv)
end

-------------------------------------------------------------------------------
--  Presentation
-------------------------------------------------------------------------------
-- The display name: BattleTag name for Battle.net, else the character name.
function C.Name(conv)
    if conv.kind == "bn" then
        local tagName = conv.tag and conv.tag:match("^([^#]+)")
        return tagName or conv.name or "?"
    end
    return conv.name or "?"
end

function C.Meta(conv)
    local parts = {}
    if conv.kind == "bn" then
        parts[1] = L["Battle.net"]
        if conv.online == false then
            parts[#parts + 1] = L["offline"]
        else
            if conv.char then parts[#parts + 1] = conv.char end
            if conv.zone then parts[#parts + 1] = conv.zone end
        end
        return parts
    end
    if conv.level then parts[#parts + 1] = tostring(conv.level) end
    local class = className(conv.class)
    if conv.race and class then
        parts[#parts + 1] = conv.race .. " " .. class
    elseif class or conv.race then
        parts[#parts + 1] = class or conv.race
    end
    if conv.online == false then
        parts[#parts + 1] = L["offline"]
    elseif conv.zone then
        parts[#parts + 1] = conv.zone
    end
    return parts
end

function C.Color(conv)
    if conv.kind == "bn" then
        local c = FRIENDS_BNET_NAME_COLOR
        if c then return c.r, c.g, c.b end
        return 0.51, 0.773, 1
    end
    if conv.class then
        if ns.Theme and ns.Theme.ClassColor then return ns.Theme.ClassColor(conv.class) end
        local c = (C_ClassColor and C_ClassColor.GetClassColor(conv.class)) or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[conv.class])
        if c then return c.r, c.g, c.b end
    end
    return 0.97, 0.97, 0.97
end

local CLASS_SHEET = "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES"

-- -> { atlas = name } | { texture = path, coords = { l, r, t, b } } | nil
function C.Icon(conv)
    if conv.kind ~= "w" or not conv.class then return nil end
    local atlas = "classicon-" .. conv.class:lower()
    if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas) then
        return { atlas = atlas }
    end
    local c = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[conv.class]
    if not c then return nil end
    -- Crop the sheet's bevel so the icon reads square, EllesmereUI style.
    local ix, iy = (c[2] - c[1]) * 0.08, (c[4] - c[3]) * 0.08
    return { texture = CLASS_SHEET, coords = { c[1] + ix, c[2] - ix, c[3] + iy, c[4] - iy } }
end

local UTF8_CHAR = "[%z\1-\127\194-\244][\128-\191]*"
local function firstChars(s, n)
    local out = {}
    for ch in s:gmatch(UTF8_CHAR) do
        out[#out + 1] = ch
        if #out == n then break end
    end
    return table.concat(out):upper()
end

function C.Initials(conv)
    if conv.kind == "bn" then
        local tagName = conv.tag and conv.tag:match("^([^#]+)")
        return tagName and firstChars(tagName, 2) or "BN"
    end
    local a, b = (conv.name or ""):match("^(%S+)%s+(%S+)")
    if a then return firstChars(a, 1) .. firstChars(b, 1) end
    return firstChars(conv.name or "?", 2)
end

-------------------------------------------------------------------------------
--  Events
-------------------------------------------------------------------------------
local function refreshOpen()
    for _, conv in ipairs(ns.Store.List()) do C.Refresh(conv) end
end

local function onUnit(unit)
    local key = unitKey(unit)
    local conv = key and ns.Store.Get(key)
    if conv then
        fromUnit(conv, unit)
        changed(conv)
    end
end

ns.On("PLAYER_TARGET_CHANGED", function() onUnit("target") end)
ns.On("UPDATE_MOUSEOVER_UNIT", function() onUnit("mouseover") end)
ns.On("FRIENDLIST_UPDATE", refreshOpen)
ns.On("GROUP_ROSTER_UPDATE", refreshOpen)
ns.On("BN_FRIEND_INFO_CHANGED", refreshOpen)
ns.On("GUILD_ROSTER_UPDATE", function()
    guildDirty = true
    refreshOpen()
end)
