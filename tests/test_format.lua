local T = T

local function load()
    local G, W, ns = T.load()
    return G, W, ns, ns.Format
end

local LINK = "|cffffffff|Hitem:2581::::::::34:::::|h[Heavy Linen Bandage]|h|r"

T.it("text under the limit is one chunk", function()
    local G, W, ns, F = load()
    local c = F.Split("hello there", 255)
    T.eq(#c, 1)
    T.eq(c[1], "hello there")
end)

T.it("empty or blank text gives no chunks", function()
    local G, W, ns, F = load()
    T.eq(#F.Split("", 255), 0)
    T.eq(#F.Split("   ", 255), 0)
end)

T.it("split prefers spaces and respects the limit", function()
    local G, W, ns, F = load()
    local words = {}
    for i = 1, 60 do words[i] = "word" .. i end
    local c = F.Split(table.concat(words, " "), 50)
    T.ok(#c > 1, "several chunks")
    for _, part in ipairs(c) do
        T.ok(#part <= 50, "within limit: " .. #part)
        T.no(part:find("^ ") or part:find(" $"), "trimmed")
    end
    T.eq(table.concat(c, " "), table.concat(words, " "), "no word lost or cut")
end)

T.it("split keeps links whole", function()
    local G, W, ns, F = load()
    local text = string.rep("abc ", 10) .. LINK .. " " .. string.rep("xyz ", 10)
    local c = F.Split(text, 60)
    local whole = false
    for _, part in ipairs(c) do
        T.ok(#part <= 60 or part == LINK, "within limit")
        if part:find(LINK, 1, true) then whole = true end
        local opens = select(2, part:gsub("|H", ""))
        local closes = select(2, part:gsub("|h", ""))
        T.eq(closes, opens * 2, "balanced link codes")
    end
    T.ok(whole, "the link survives in one piece")
end)

T.it("split never cuts a UTF-8 character", function()
    local G, W, ns, F = load()
    local text = string.rep("ä", 200) -- 400 bytes, no spaces
    local c = F.Split(text, 255)
    T.eq(#c, 2)
    for _, part in ipairs(c) do
        T.ok(#part <= 255, "limit")
        T.ok(part:find("^[\195][\164]") and #part % 2 == 0, "whole characters only")
    end
end)

T.it("Linkify wraps http and www URLs", function()
    local G, W, ns, F = load()
    local out = F.Linkify("see https://polestar.guide/community now")
    T.ok(out:find("|Hsotto:url:https://polestar.guide/community|h", 1, true), "http link")
    T.ok(out:find(" now$"), "text after kept")
    out = F.Linkify("www.wowhead.com")
    T.ok(out:find("|Hsotto:url:www.wowhead.com|h", 1, true), "www link")
end)

T.it("Linkify finds bare domains with a path", function()
    local G, W, ns, F = load()
    local out = F.Linkify("route on wowhead.com/forever/rfk")
    T.ok(out:find("|Hsotto:url:wowhead.com/forever/rfk|h", 1, true), out)
end)

T.it("Linkify strips trailing punctuation", function()
    local G, W, ns, F = load()
    local out = F.Linkify("look (https://example.com/a).")
    T.ok(out:find("|Hsotto:url:https://example.com/a|h", 1, true), out)
    T.ok(out:find("|h|r%)%.$"), "punctuation stays outside: " .. out)
end)

T.it("Linkify leaves existing links and plain words alone", function()
    local G, W, ns, F = load()
    T.eq(F.Linkify(LINK), LINK)
    T.eq(F.Linkify("e.g. this is fine"), "e.g. this is fine")
    T.eq(F.Linkify("version 1.2.3"), "version 1.2.3")
end)

T.it("Plain strips codes and keeps link text", function()
    local G, W, ns, F = load()
    T.eq(F.Plain("a " .. LINK .. " b"), "a [Heavy Linen Bandage] b")
end)

T.it("Time uses the 24-hour clock when the game does", function()
    local G, W, ns, F = load()
    local t = os.time({ year = 2026, month = 11, day = 12, hour = 14, min = 2 })
    T.eq(F.Time(t), "14:02")
    W.cvars.timeMgrUseMilitaryTime = "0"
    T.eq(F.Time(t), "2:02 PM")
end)

T.it("Day labels today, yesterday, weekday and date", function()
    local G, W, ns, F = load()
    local now = os.time({ year = 2026, month = 11, day = 12, hour = 14 })
    T.eq(F.Day(now - 3600, now), "Today")
    T.eq(F.Day(now - 86400, now), "Yesterday")
    T.eq(F.Day(now - 3 * 86400, now), os.date("%A", now - 3 * 86400))
    T.eq(F.Day(now - 30 * 86400, now), "Oct 13")
end)

T.it("DayKey groups by calendar day", function()
    local G, W, ns, F = load()
    local a = os.time({ year = 2026, month = 11, day = 12, hour = 0, min = 5 })
    local b = os.time({ year = 2026, month = 11, day = 12, hour = 23, min = 55 })
    local c = os.time({ year = 2026, month = 11, day = 13, hour = 0, min = 1 })
    T.eq(F.DayKey(a), F.DayKey(b))
    T.ok(F.DayKey(b) ~= F.DayKey(c), "next day differs")
end)
