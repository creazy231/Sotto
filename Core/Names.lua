-------------------------------------------------------------------------------
--  Sotto: character names. WoW Forever names are a first name and a surname
--  without a realm ("Ayla Brightwind"); the chat box also accepts them as
--  "Ayla-Brightwind". Other clients send "Name-Realm" for other realms. A
--  hyphen after a single word is a surname where the client has surnames
--  (RegionalUniqueNamesEnabled), otherwise it starts the realm. The player's
--  own realm is dropped in every form it can arrive in.
-------------------------------------------------------------------------------
local _, ns = ...
local N = {}
ns.Names = N

local function separator()
    local c = Constants and Constants.CharacterNameSeparatorConsts
    return (c and c.CHARACTERNAME_SURNAME_SEPARATOR) or " "
end

local function surnames()
    return RegionalUniqueNamesEnabled ~= nil and RegionalUniqueNamesEnabled() and true or false
end

local function isOwnRealm(realm)
    local display = GetRealmName and GetRealmName()
    local normalized = GetNormalizedRealmName and GetNormalizedRealmName()
    if realm == display or realm == normalized then return true end
    return normalized ~= nil and (realm:gsub("[%s%-]", "")) == normalized
end

-- -> name, realm (realm nil when absent or the player's own); nil for bad input,
-- including anything with a "|" escape (a Battle.net account token, a link).
local function split(name)
    if ns.IsSecret(name) or type(name) ~= "string" or name == "" then return nil end
    if name:find("|", 1, true) then return nil end
    local n, r = name:match("^([^%-]+)%-(.+)$")
    if not n then return name, nil end
    if surnames() and not n:find("%s") then
        -- "First-Last" (or "First-Last-Realm"): the hyphen is the surname's.
        local last, realm = r:match("^([^%-]+)%-(.+)$")
        n = n .. separator() .. (last or r)
        if not last then return n, nil end
        r = realm
    end
    if isOwnRealm(r) then return n, nil end
    return n, r
end

-- Conversation key: lower case, own realm dropped. nil for bad input.
function N.Key(name)
    local n, r = split(name)
    if not n then return nil end
    return (r and (n .. "-" .. r) or n):lower()
end

-- First word, realm dropped: the name in message group headers.
function N.Short(name)
    local n = split(name)
    if not n then return "" end
    return n:match("^(%S+)") or n
end

-- Full name for headers and tooltips, own realm dropped.
function N.Display(name)
    local n, r = split(name)
    if not n then return "" end
    return r and (n .. "-" .. r) or n
end

-- The full name of a unit ("Ayla Brightwind", or "Bob-Realm" elsewhere), nil
-- when it is unknown or secret.
function N.Unit(unit)
    if surnames() and NameUtil and NameUtil.GetUnmodifiedUnitFullName then
        local ok, full = pcall(NameUtil.GetUnmodifiedUnitFullName, unit)
        if ok and not ns.IsSecret(full) and type(full) == "string" and full ~= "" then return full end
    end
    local name, second = UnitName(unit)
    if ns.IsSecret(name, second) or type(name) ~= "string" or name == "" then return nil end
    if type(second) ~= "string" or second == "" then return name end
    if surnames() then return name .. separator() .. second end
    return name .. "-" .. second
end
