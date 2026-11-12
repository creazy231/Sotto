-------------------------------------------------------------------------------
--  Sotto: character names. WoW Forever names are two words without a realm
--  ("Ayla Brightwind"); other clients send "Name-Realm" for other realms. Names
--  never contain "-", so the first "-" starts the realm. The player's own
--  realm is dropped in every form it can arrive in.
-------------------------------------------------------------------------------
local _, ns = ...
local N = {}
ns.Names = N

local function isOwnRealm(realm)
    local display = GetRealmName and GetRealmName()
    local normalized = GetNormalizedRealmName and GetNormalizedRealmName()
    if realm == display or realm == normalized then return true end
    return normalized ~= nil and (realm:gsub("[%s%-]", "")) == normalized
end

-- -> name, realm (realm nil when absent or the player's own); nil for bad input
local function split(name)
    if ns.IsSecret(name) or type(name) ~= "string" or name == "" then return nil end
    local n, r = name:match("^([^%-]+)%-(.+)$")
    if not n then return name, nil end
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
