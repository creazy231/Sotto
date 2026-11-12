-------------------------------------------------------------------------------
--  Sotto dev tool: draws what the addon built inside the fake client as an
--  HTML page, so the real window can be compared with the approved mockup
--  without the game. Every visible texture and font string under the given
--  frames is placed from its resolved anchors, with its colour, tint, texture
--  crop, gradient, font, size and draw order.
--
--  Usage (from the addon folder):
--    luajit tools/render_ui.lua <out.html> <scenario>
--  scenarios: chat, new, lock, empty, settings, toast
--  Media must be converted first: python3 -I tools/tga2png.py <render-dir>
-------------------------------------------------------------------------------
package.path = "./?.lua;" .. package.path
local T = dofile("tests/harness.lua")

local out, scenario = arg[1] or "render.html", arg[2] or "chat"
local EXPRESSWAY = "Interface\\AddOns\\EllesmereUI\\media\\fonts\\Expressway.TTF"

local G, W, ns = T.load({
    eui = { font = EXPRESSWAY, accent = { 0, 0.81, 1 } },
    setup = function(G, W)
        for _, c in ipairs({ "warrior", "shaman", "hunter", "mage", "druid" }) do W.atlases["classicon-" .. c] = {} end
        W.guids["Player-1"] = { classLoc = "Warrior", classFile = "WARRIOR", raceLoc = "Orc" }
        W.guids["Player-2"] = { classLoc = "Shaman", classFile = "SHAMAN", raceLoc = "Tauren" }
        W.guids["Player-3"] = { classLoc = "Hunter", classFile = "HUNTER", raceLoc = "Troll" }
        W.guids["Player-4"] = { classLoc = "Mage", classFile = "MAGE", raceLoc = "Undead" }
        W.friends = {
            { name = "Tarin Ashgrove", level = 34, className = "Warrior", area = "Desolace", connected = true },
            { name = "Kaja Stormhoof", level = 33, className = "Shaman", area = "Thousand Needles", connected = true },
            { name = "Nori Bloodfang", level = 35, className = "Hunter", area = "Stranglethorn Vale", connected = true },
            { name = "Vex Morrow", level = 31, className = "Mage", connected = false },
        }
        W.bnFriends = { { bnetAccountID = 5, accountName = "|Kq5|k", battleTag = "Alex#1234",
            gameAccountInfo = { isOnline = true, clientProgram = "WoW", characterName = "Brann", areaName = "Orgrimmar",
                characterLevel = 35, className = "Hunter", raceName = "Troll" } } }
    end,
})

-------------------------------------------------------------------------------
--  Scenario (the mockup's conversation)
-------------------------------------------------------------------------------
local S = ns.Store
local now = G.time()
local function add(conv, d, m, ago) S.Add(conv, d, m, now - ago) end
local vex = S.Ensure("w", "Vex Morrow"); ns.Contacts.Learn(vex, "Player-4"); add(vex, "i", "see you tomorrow", 4 * 86400)
local nori = S.Ensure("w", "Nori Bloodfang"); ns.Contacts.Learn(nori, "Player-3"); add(nori, "i", "thanks for the trade", 3 * 86400)
local alex = S.Ensure("bn", "|Kq5|k", { tag = "Alex#1234", bnID = 5 }); add(alex, "i", "you around tonight?", 2 * 86400)
local kaja = S.Ensure("w", "Kaja Stormhoof"); ns.Contacts.Learn(kaja, "Player-2")
add(kaja, "o", "gg, thanks for the heals in WC", 86400 + 300)
add(kaja, "i", "np! add me, we should run RFK sometime", 86400 + 240)
local tarin = S.Ensure("w", "Tarin Ashgrove"); ns.Contacts.Learn(tarin, "Player-1")
local t0 = now - 240
S.Add(tarin, "i", "hey, saw you in Desolace! doing |cffffd100|Hquest:1|h[Kodo Roundup]|h|r too?", t0)
S.Add(tarin, "i", "could team up, the graveyard is packed", t0 + 5)
S.Add(tarin, "o", "yes please, that would be great", t0 + 60)
S.Add(tarin, "o", "omw from Ghost Walker Post", t0 + 64)
S.Add(tarin, "i", "inviting you now, meet me at the gate", t0 + 120)
for _, c in ipairs({ vex, nori, alex, kaja, tarin }) do ns.Contacts.Refresh(c) end
vex.online = false
kaja.unread = 0

if scenario == "chat" then
    ns.UI.Open(tarin, { focus = true, text = "sure, 2 min, finishing this quest" })
    add(kaja, "i", "lf healer for Razorfen Kraul? we have tank + 2 dps", 30)
    S.MarkUnread(kaja, 2)
elseif scenario == "new" then
    add(kaja, "i", "lf healer for Razorfen Kraul? we have tank + 2 dps", 30)
    add(kaja, "i", "route on wowhead.com/forever/rfk", 25)
    S.MarkUnread(kaja, 2)
    S.MarkUnread(alex, 1)
    ns.UI.Open(kaja)
elseif scenario == "lock" then
    ns.UI.Open(tarin)
    W.lockdown = true
    W.fire("ENCOUNTER_START")
    S.MarkUnread(kaja, 2)
elseif scenario == "empty" then
    G.SottoDB.chars[ns.CharKey()].convs = {}
    G.SottoDB.bn = {}
    ns.UI.Toggle()
elseif scenario == "settings" then
    W.cvars.whisperMode = "inline"
    S.MarkUnread(kaja, 2)
    ns.UI.ShowSettings()
elseif scenario == "toast" then
    W.combat = true
    W.chat("CHAT_MSG_WHISPER", W.whisperArgs("lf healer for Razorfen Kraul? we have tank + 2 dps", "Kaja Stormhoof",
        { guid = "Player-2" }))
end
W.advance(0)

-------------------------------------------------------------------------------
--  Collect and draw
-------------------------------------------------------------------------------
local LAYERS = { BACKGROUND = 1, BORDER = 2, ARTWORK = 3, OVERLAY = 4, HIGHLIGHT = 5 }
local STRATA = { BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4, DIALOG = 5, FULLSCREEN = 6, FULLSCREEN_DIALOG = 7, TOOLTIP = 8 }
local SH = 1080
local items, seq = {}, 0

local function strataOf(f)
    while f do
        if f._strata then return STRATA[f._strata] or 3 end
        f = f._parent
    end
    return 3
end

local function alphaOf(o)
    local a = 1
    while o do a = a * (o._alpha or 1); o = o._parent end
    return a
end

local function clipOf(o)
    local f, box = o._parent, nil
    while f do
        if f._clips then
            local r = W.rect(f)
            local c = { r[1], r[2], r[1] + r[3], r[2] + r[4] }
            if box then
                box = { math.max(box[1], c[1]), math.max(box[2], c[2]), math.min(box[3], c[3]), math.min(box[4], c[4]) }
            else
                box = c
            end
        end
        f = f._parent
    end
    return box
end

local function rgba(c, a)
    return string.format("rgba(%d,%d,%d,%.3f)", (c[1] or 1) * 255 + 0.5, (c[2] or 1) * 255 + 0.5, (c[3] or 1) * 255 + 0.5,
        (c[4] or 1) * (a or 1))
end

local function esc(s) return (s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")) end

local function richText(text)
    text = text:gsub("|K.-|k", "Alex"):gsub("|H.-|h(.-)|h", "%1"):gsub("|T.-|t", "")
    local html, pos, open = {}, 1, false
    while pos <= #text do
        local s, e, hex = text:find("|c%x%x(%x%x%x%x%x%x)", pos)
        local rs, re = text:find("|r", pos, true)
        if s and (not rs or s < rs) then
            html[#html + 1] = esc(text:sub(pos, s - 1))
            if open then html[#html + 1] = "</span>" end
            html[#html + 1] = '<span style="color:#' .. hex .. '">'
            open, pos = true, e + 1
        elseif rs then
            html[#html + 1] = esc(text:sub(pos, rs - 1))
            if open then html[#html + 1] = "</span>"; open = false end
            pos = re + 1
        else
            html[#html + 1] = esc(text:sub(pos))
            break
        end
    end
    if open then html[#html + 1] = "</span>" end
    return table.concat(html)
end

local function mediaPath(tex)
    local rel = tex:match("^Interface\\AddOns\\Sotto\\Media\\(.+)$")
    if rel then return "media/" .. rel:gsub("\\", "/") .. ".png" end
end

local function visit(f)
    if not f:IsVisible() then return end
    local level = f._level or 1
    if f._type == "EditBox" and f._text and f._text ~= "" then
        local fs = f:CreateFontString(nil, "OVERLAY")
        fs._font, fs._textColor, fs._text = f._font, f._textColor, f._text
        fs:SetPoint("LEFT", f, "LEFT", (f._insets and f._insets[1]) or 0, 0)
        fs._wrap = false
        if W.focus == f then fs._text = fs._text .. "|"
        end
    end
    for i, r in ipairs(f._regions) do
        if r._shown ~= false then
            seq = seq + 1
            items[#items + 1] = { r = r, z = { strataOf(f), level, LAYERS[r._layer or "ARTWORK"] or 3, r._sub or 0, seq } }
        end
    end
    for _, c in ipairs(f._children) do visit(c) end
end

for _, root in ipairs({ G.SottoWindow, G.SottoMenu, G.SottoCopyBox }) do if root then visit(root) end end
for _, t in ipairs(ns.Toast.active) do visit(t) end
table.sort(items, function(a, b)
    for k = 1, 5 do if a.z[k] ~= b.z[k] then return a.z[k] < b.z[k] end end
    return false
end)

local html = {}
local function emit(div, clip, z)
    if clip then
        local inset = string.format("%dpx %dpx %dpx %dpx", SH - clip[4], 1920 - clip[3], clip[2], clip[1])
        html[#html + 1] = '<div style="position:absolute;left:0;top:0;width:1920px;height:1080px;z-index:' .. z
            .. ';clip-path:inset(' .. inset .. ')">' .. div .. "</div>"
    else
        html[#html + 1] = div
    end
end

for z, it in ipairs(items) do
    local r = it.r
    local a = alphaOf(r)
    if a > 0.001 then
        local rc = W.rect(r)
        local left, bottom, w, h = rc[1], rc[2], rc[3], rc[4]
        local top = SH - bottom - h
        local clip = clipOf(r)
        if r._type == "Texture" then
            if w > 0 and h > 0 then
                local style = string.format("position:absolute;left:%.2fpx;top:%.2fpx;width:%.2fpx;height:%.2fpx;opacity:%.3f;", left, top, w, h, a)
                if r._color and r._gradient then
                    local mn, mx = r._gradient[2], r._gradient[3]
                    style = style .. string.format("background:linear-gradient(to top,%s,%s);", rgba({ mn.r, mn.g, mn.b, mn.a }), rgba({ mx.r, mx.g, mx.b, mx.a }))
                elseif r._color then
                    style = style .. "background:" .. rgba(r._color) .. ";"
                else
                    local path = (r._texture and mediaPath(r._texture))
                    if r._atlas then path = "class/" .. r._atlas:gsub("classicon%-", "class-") .. ".png" end
                    if path then
                        local tc = r._texcoord or { 0, 1, 0, 1 }
                        local l, rr, t, b = tc[1], tc[2], tc[3], tc[4]
                        local fw, fh = w / (rr - l), h / (b - t)
                        local size = string.format("%.2fpx %.2fpx", fw, fh)
                        local pos = string.format("%.2fpx %.2fpx", -l * fw, -t * fh)
                        if r._vertex and not r._atlas and not path:find("minimap") then
                            style = style .. "background:" .. rgba(r._vertex) .. ";"
                                .. "-webkit-mask-image:url(" .. path .. ");-webkit-mask-size:" .. size .. ";-webkit-mask-position:" .. pos .. ";-webkit-mask-repeat:no-repeat;"
                        else
                            style = style .. "background-image:url(" .. path .. ");background-size:" .. size .. ";background-position:" .. pos .. ";background-repeat:no-repeat;"
                        end
                        if r._desat then style = style .. "filter:grayscale(1);" end
                    else
                        style = nil
                    end
                end
                if style then emit('<div style="' .. style .. 'z-index:' .. z .. '"></div>', clip, z) end
            end
        elseif r._type == "FontString" and r._text and r._text ~= "" then
            local font = r._font or { "", 12 }
            local family = font[1]:find("Bold") and "ExpresswayBold" or (font[1]:find("Expressway") and "Expressway" or "sans-serif")
            local color = r._textColor and rgba(r._textColor) or "#fff"
            local style = string.format("position:absolute;font-family:%s;font-size:%.1fpx;line-height:%.1fpx;color:%s;"
                .. "text-shadow:1px 1px 0 rgba(0,0,0,.6);opacity:%.3f;z-index:%d;", family, font[2], font[2] + 2, color, a, z)
            local twoSided = false
            local L, R
            for _, p in ipairs(r._points) do
                if p[1]:find("LEFT") then L = true elseif p[1]:find("RIGHT") then R = true end
            end
            twoSided = (L and R) or (r._w and r._w > 0)
            local just = (r._justifyH or "LEFT"):lower()
            if twoSided then
                style = style .. string.format("left:%.2fpx;top:%.2fpx;width:%.2fpx;text-align:%s;", left, top, w, just)
                if r._wrap == false then
                    style = style .. "white-space:nowrap;overflow:hidden;text-overflow:ellipsis;"
                else
                    style = style .. "white-space:normal;overflow-wrap:anywhere;"
                end
            else
                local p = r._points[1]
                local x, y = left, top
                local tx, ty = "0", "0"
                if p then
                    local prc = W.rect(p[2])
                    local px = p[3]:find("LEFT") and prc[1] or (p[3]:find("RIGHT") and prc[1] + prc[3]) or prc[1] + prc[3] / 2
                    local py = p[3]:find("TOP") and prc[2] + prc[4] or (p[3]:find("BOTTOM") and prc[2]) or prc[2] + prc[4] / 2
                    x, y = px + (p[4] or 0), SH - (py + (p[5] or 0))
                    tx = p[1]:find("LEFT") and "0" or (p[1]:find("RIGHT") and "-100%" or "-50%")
                    ty = p[1]:find("TOP") and "0" or (p[1]:find("BOTTOM") and "-100%" or "-50%")
                end
                style = style .. string.format("left:%.2fpx;top:%.2fpx;white-space:pre;transform:translate(%s,%s);text-align:%s;", x, y, tx, ty, just)
            end
            emit('<div style="' .. style .. '">' .. richText(r._text):gsub("\n", "<br>") .. "</div>", clip, z)
        end
    end
end

local win = W.rect(G.SottoWindow)
local doc = [[<!DOCTYPE html><html><head><meta charset="utf-8"><title>Sotto render</title><style>
@font-face{font-family:Expressway;src:url(fonts/expressway.ttf)}
@font-face{font-family:ExpresswayBold;src:url(fonts/expressway-bold.ttf)}
html,body{margin:0;background:#0b0b0c}
#stage{position:relative;width:1920px;height:1080px;overflow:hidden;background:url(backdrop.jpg) 0 0/1920px 1080px;
  -webkit-font-smoothing:antialiased;transform-origin:0 0}
</style></head><body><div id="stage">]] .. table.concat(html, "\n") .. [[</div>
<script>window.SOTTO_WIN={x:]] .. win[1] .. [[,y:]] .. (SH - win[2] - win[4]) .. [[,w:]] .. win[3] .. [[,h:]] .. win[4] .. [[};</script>
</body></html>]]
local fh = io.open(out, "w")
fh:write(doc)
fh:close()
print("wrote " .. out .. " (" .. #items .. " regions)")
