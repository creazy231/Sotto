-------------------------------------------------------------------------------
--  Sotto: text formatting. Pure functions.
--    Split     long text into chat-sized messages, never inside a link or a
--              UTF-8 character
--    Linkify   URLs into clickable "sotto:url:" hyperlinks
--    Plain     codes stripped (previews, copy box)
--    Time/Day  labels for the message log
-------------------------------------------------------------------------------
local _, ns = ...
local F = {}
ns.Format = F

local floor = math.floor

-- Link colour (Polestar's link blue); the theme may change it.
F.linkColor = "ff94c9ff"

-------------------------------------------------------------------------------
--  Tokens: hyperlinks (with their colour codes) are atomic.
-------------------------------------------------------------------------------
local LINK_PATTERNS = {
    "|c%x%x%x%x%x%x%x%x|H.-|h.-|h|r",
    "|cn[^:|]+:|H.-|h.-|h|r",
    "|H.-|h.-|h",
}

local function nextLink(text, pos)
    local bs, be
    for i = 1, #LINK_PATTERNS do
        local s, e = text:find(LINK_PATTERNS[i], pos)
        if s and (not bs or s < bs) then bs, be = s, e end
    end
    return bs, be
end

-- -> { { s = text, link = bool }, ... }
local function tokenize(text)
    local out, pos = {}, 1
    while pos <= #text do
        local s, e = nextLink(text, pos)
        if not s then
            out[#out + 1] = { s = text:sub(pos) }
            break
        end
        if s > pos then out[#out + 1] = { s = text:sub(pos, s - 1) } end
        out[#out + 1] = { s = text:sub(s, e), link = true }
        pos = e + 1
    end
    return out
end
F.Tokenize = tokenize

local function trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end

-------------------------------------------------------------------------------
--  Split
-------------------------------------------------------------------------------
-- Longest prefix of s that is at most n bytes and ends on a character boundary.
local function utf8Cut(s, n)
    if n >= #s then return #s end
    local cut = n
    while cut > 0 do
        local b = s:byte(cut + 1)
        if not b or b < 0x80 or b >= 0xC0 then break end
        cut = cut - 1
    end
    return cut
end

-- text cut to at most n bytes on a character boundary, with "…" when cut.
function F.Truncate(text, n)
    if type(text) ~= "string" or #text <= n then return text end
    return text:sub(1, utf8Cut(text, n)) .. "…"
end

-- Cuts one over-long word; full pieces go to out, the rest is returned.
local function hardSplit(word, limit, out)
    local cur = ""
    for _, tok in ipairs(tokenize(word)) do
        if tok.link then
            if cur ~= "" and #cur + #tok.s > limit then out[#out + 1] = cur; cur = "" end
            cur = cur .. tok.s
        else
            local s = tok.s
            while #s > 0 do
                local room = limit - #cur
                local n = room > 0 and utf8Cut(s, room) or 0
                if n == 0 then
                    if cur == "" then n = utf8Cut(s, limit) end
                    if n == 0 then out[#out + 1] = cur; cur = "" end
                end
                if n > 0 then
                    cur = cur .. s:sub(1, n)
                    s = s:sub(n + 1)
                end
            end
        end
    end
    return cur
end

function F.Split(text, limit)
    limit = limit or 255
    if type(text) ~= "string" then return {} end
    text = trim(text)
    if text == "" then return {} end
    if #text <= limit then return { text } end

    -- Protect links from the word split: each becomes "\1n\2".
    local links, parts = {}, {}
    for _, tok in ipairs(tokenize(text)) do
        if tok.link then
            links[#links + 1] = tok.s
            parts[#parts + 1] = "\1" .. #links .. "\2"
        else
            parts[#parts + 1] = tok.s
        end
    end
    local protected = table.concat(parts)

    local out, chunk = {}, ""
    for raw in protected:gmatch("%S+") do
        local word = raw:gsub("\1(%d+)\2", function(i) return links[tonumber(i)] end)
        local candidate = chunk == "" and word or (chunk .. " " .. word)
        if #candidate <= limit then
            chunk = candidate
        else
            if chunk ~= "" then out[#out + 1] = chunk end
            if #word <= limit then
                chunk = word
            else
                chunk = hardSplit(word, limit, out)
            end
        end
    end
    if chunk ~= "" then out[#out + 1] = chunk end
    return out
end

-------------------------------------------------------------------------------
--  Linkify
-------------------------------------------------------------------------------
local TLDS = {
    com = true, net = true, org = true, io = true, gg = true, de = true, eu = true, co = true, uk = true,
    tv = true, me = true, app = true, dev = true, info = true, fr = true, ru = true, es = true, it = true,
    nl = true, pl = true, be = true, at = true, ch = true, guide = true, gl = true, ly = true, to = true,
}

local function isURL(s)
    local lower = s:lower()
    if lower:find("^https?://[%w%-]") then return true end
    if lower:find("^www%.[%w%-]+%.%a") then return true end
    local host = lower:match("^([%w%-%.]+)/") or lower:match("^([%w%-%.]+)$")
    if not host then return false end
    local tld = host:match("%.(%a+)$")
    return tld ~= nil and TLDS[tld] == true and host:find("^[%w%-]+%.") ~= nil
end

local function linkText(url)
    return "|c" .. F.linkColor .. "|Hsotto:url:" .. url .. "|h" .. url .. "|h|r"
end
F.LinkText = linkText

local function linkifyWord(word)
    local lead, core = word:match("^([%(%[\"']*)(.*)$")
    local tail = ""
    while true do
        local last = core:sub(-1)
        if last == "" then break end
        if last:find("[%.,;:!%?\"']") then
            tail = last .. tail
            core = core:sub(1, -2)
        elseif last == ")" or last == "]" then
            local open = last == ")" and "%(" or "%["
            local close = last == ")" and "%)" or "%]"
            local opens = select(2, core:gsub(open, ""))
            local closes = select(2, core:gsub(close, ""))
            if closes > opens then
                tail = last .. tail
                core = core:sub(1, -2)
            else
                break
            end
        else
            break
        end
    end
    if core ~= "" and isURL(core) then return lead .. linkText(core) .. tail end
    return word
end

function F.Linkify(text)
    if type(text) ~= "string" or text == "" then return text end
    local out = {}
    for _, tok in ipairs(tokenize(text)) do
        out[#out + 1] = tok.link and tok.s or (tok.s:gsub("%S+", linkifyWord))
    end
    return table.concat(out)
end

-------------------------------------------------------------------------------
--  Plain text
-------------------------------------------------------------------------------
function F.Plain(text)
    if type(text) ~= "string" then return "" end
    text = text:gsub("|H.-|h(.-)|h", "%1")
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|cn[^:|]+:", ""):gsub("|r", "")
    text = text:gsub("|T.-|t", ""):gsub("|A.-|a", "")
    return text
end

-------------------------------------------------------------------------------
--  Time and day labels
-------------------------------------------------------------------------------
function F.Time(t)
    if GetCVarBool and GetCVarBool("timeMgrUseMilitaryTime") then
        return date("%H:%M", t)
    end
    return tostring(tonumber(date("%I", t))) .. date(":%M %p", t)
end

local function dayNumber(t)
    local d = date("*t", t)
    return floor(time({ year = d.year, month = d.month, day = d.day, hour = 12 }) / 86400)
end

function F.DayKey(t)
    return date("%Y-%m-%d", t)
end

function F.Day(t, now)
    local diff = dayNumber(now or time()) - dayNumber(t)
    if diff <= 0 then return ns.L["Today"] end
    if diff == 1 then return ns.L["Yesterday"] end
    if diff < 7 then return date("%A", t) end
    return (date("%b %d", t):gsub(" 0", " "))
end
