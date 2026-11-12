-------------------------------------------------------------------------------
--  Sotto: namespace, strings, secret guards, and two small buses:
--    ns.On / ns.Off        game events (one hidden frame for the addon)
--    ns.Listen / ns.Fire   Sotto's own messages between modules
--  Handlers run protected: one failing handler never stops the others; its
--  error is reported through the game's error handler afterwards.
-------------------------------------------------------------------------------
local ADDON, ns = ...
ns.name = ADDON

local getMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
ns.version = (getMeta and getMeta(ADDON, "Version")) or "1.0.0"

-- English strings. A missing key shows the key itself.
ns.L = setmetatable({}, { __index = function(_, k) return k end })

-------------------------------------------------------------------------------
--  Secret values (12.x engine): never compare, index or measure one.
-------------------------------------------------------------------------------
local issecretvalue = issecretvalue
local hasanysecretvalues = hasanysecretvalues

function ns.IsSecret(...)
    if hasanysecretvalues then return hasanysecretvalues(...) and true or false end
    if issecretvalue then
        for i = 1, select("#", ...) do
            if issecretvalue((select(i, ...))) then return true end
        end
    end
    return false
end

-- True while the client hides chat from addons (encounters, Mythic+, PvP,
-- restricted maps). An unreadable answer counts as locked.
function ns.InLockdown()
    local f = C_ChatInfo and C_ChatInfo.InChatMessagingLockdown
    if not f then return false end
    local ok, v = pcall(f)
    if not ok then return false end
    if ns.IsSecret(v) then return true end
    return v and true or false
end

-------------------------------------------------------------------------------
--  Protected dispatch
-------------------------------------------------------------------------------
local function report(errors)
    local handler = geterrorhandler and geterrorhandler()
    for i = 1, #errors do
        if handler then handler(errors[i]) end
    end
end

local function dispatch(list, ...)
    if not list then return end
    local errors
    -- Copy first: a handler may add or remove handlers.
    local n = #list
    local copy = {}
    for i = 1, n do copy[i] = list[i] end
    for i = 1, n do
        local ok, err = pcall(copy[i], ...)
        if not ok then
            errors = errors or {}
            errors[#errors + 1] = err
        end
    end
    if errors then report(errors) end
end

function ns.Safe(fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then report({ err }) end
    return ok
end

-------------------------------------------------------------------------------
--  Game events
-------------------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
local eventHandlers = {}
eventFrame:SetScript("OnEvent", function(_, event, ...)
    dispatch(eventHandlers[event], event, ...)
end)

function ns.On(event, fn)
    local list = eventHandlers[event]
    if not list then
        -- An event this client does not know must not break the addon.
        if not pcall(eventFrame.RegisterEvent, eventFrame, event) then return false end
        list = {}
        eventHandlers[event] = list
    end
    list[#list + 1] = fn
    return true
end

function ns.Off(event, fn)
    local list = eventHandlers[event]
    if not list then return end
    for i = #list, 1, -1 do
        if list[i] == fn then table.remove(list, i) end
    end
    if #list == 0 then
        eventHandlers[event] = nil
        eventFrame:UnregisterEvent(event)
    end
end

-------------------------------------------------------------------------------
--  Messages between modules
-------------------------------------------------------------------------------
local listeners = {}

function ns.Listen(msg, fn)
    local list = listeners[msg]
    if not list then list = {}; listeners[msg] = list end
    list[#list + 1] = fn
end

function ns.Fire(msg, ...)
    dispatch(listeners[msg], ...)
end

-------------------------------------------------------------------------------
--  Small helpers
-------------------------------------------------------------------------------
function ns.After(seconds, fn)
    C_Timer.After(seconds, fn)
end

function ns.Print(text)
    local frame = DEFAULT_CHAT_FRAME
    if frame and frame.AddMessage then
        frame:AddMessage("|cffff7d0aSotto|r: " .. tostring(text))
    end
end
