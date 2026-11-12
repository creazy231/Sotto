-------------------------------------------------------------------------------
--  Sotto: saved variables (SottoDB, account-wide) and settings.
--    settings   the nine options of the settings view
--    window     position and size of the window
--    chars      per character: { [charKey] = { convs = { [key] = conv } } }
--    bn         Battle.net conversations, shared by all characters
-------------------------------------------------------------------------------
local ADDON, ns = ...

ns.DEFAULTS = {
    settings = {
        openOn = "nocombat",   -- "always" | "nocombat" | "never"
        sound = "chime",       -- "chime" | "game" | "none"
        hideInChat = true,
        intercept = true,
        accent = "class",      -- "class" | "eui"
        fontSize = 13,
        fadeIdle = true,
        keepDays = 30,         -- 0 = until logout
        minimap = true,
    },
    window = { point = "BOTTOMLEFT", x = 22, y = 328, w = 410, h = 306 },
    minimapAngle = 215,
}

local function fill(target, defaults)
    for k, v in pairs(defaults) do
        if type(v) == "table" then
            if type(target[k]) ~= "table" then target[k] = {} end
            fill(target[k], v)
        elseif target[k] == nil then
            target[k] = v
        end
    end
end

function ns.Get(key)
    local db = ns.DB
    local v = db and db.settings[key]
    if v == nil then v = ns.DEFAULTS.settings[key] end
    return v
end

function ns.Set(key, value)
    if not ns.DB then return end
    if ns.DB.settings[key] == value then return end
    ns.DB.settings[key] = value
    ns.Fire("SETTING_CHANGED", key, value)
end

-- The logged-in character: its GUID (on WoW Forever UnitName returns first
-- name and surname separately, so a name key could merge two characters).
local charKey
function ns.CharKey()
    if charKey then return charKey end
    local guid = UnitGUID and UnitGUID("player")
    if not ns.IsSecret(guid) and type(guid) == "string" and guid ~= "" then
        charKey = guid
        return guid
    end
    return (UnitName("player") or "?") .. "-" .. (GetRealmName() or "?")
end

ns.On("ADDON_LOADED", function(_, name)
    if name ~= ADDON then return end
    if type(SottoDB) ~= "table" then SottoDB = {} end
    fill(SottoDB, ns.DEFAULTS)
    if type(SottoDB.chars) ~= "table" then SottoDB.chars = {} end
    if type(SottoDB.bn) ~= "table" then SottoDB.bn = {} end
    SottoDB.schema = 1
    ns.DB = SottoDB
    ns.Fire("DB_READY")
end)
