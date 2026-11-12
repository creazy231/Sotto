-------------------------------------------------------------------------------
--  Sotto: the rail. The mark on top, one badge per open conversation (newest
--  first): a 28 px class icon, or Battle.net initials, with an unread pill;
--  the active one carries the accent bar; offline contacts are greyed out.
--  "+" (new conversation) and the gear sit at the bottom.
-------------------------------------------------------------------------------
local _, ns = ...
local R = {}
ns.Rail = R

local W, L = ns.W, ns.L
local floor, max, min = math.floor, math.max, math.min

local ROW = 40          -- badge row height + gap
R.badges = {}
local pool = {}
local list, offset = nil, 0

-------------------------------------------------------------------------------
--  Badges
-------------------------------------------------------------------------------
local function preview(conv)
    local m = conv.msgs[#conv.msgs]
    if not m then return nil end
    local text = ns.Format.Truncate(ns.Format.Plain(m.m or ""), 64)
    local who = m.d == "o" and L["You"] or (m.d == "s" and "" or ns.Names.Short(ns.Contacts.Name(conv)))
    return (who ~= "" and (who .. ": ") or "") .. text
end
R.Preview = preview

local function showTip(b)
    local conv = b.conv
    if not conv then return end
    local r, g, bl = ns.Contacts.Color(conv)
    local lines = {}
    local meta = table.concat(ns.Contacts.Meta(conv), " · ")
    if meta ~= "" then lines[#lines + 1] = { meta, 0.79, 0.8, 0.81 } end
    local p = preview(conv)
    if p then lines[#lines + 1] = { p, 0.64, 0.65, 0.66 } end
    if (conv.unread or 0) > 0 then
        lines[#lines + 1] = { string.format(L["%d unread"], conv.unread), ns.Theme.Accent() }
    end
    GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
    GameTooltip:SetText(ns.Contacts.Name(conv), r, g, bl)
    for _, line in ipairs(lines) do GameTooltip:AddLine(line[1], line[2], line[3], line[4], true) end
    GameTooltip:Show()
end

local function convMenu(b)
    local conv = b.conv
    W.Menu(b, {
        { text = L["Open"], func = function() ns.UI.Open(conv) end },
        { text = L["Clear history"], func = function() ns.Store.Clear(conv) end },
        { text = L["Close conversation"], color = "danger", func = function() ns.Store.Close(conv) end },
    }, 150)
end

local function newBadge()
    local b = CreateFrame("Button", nil, list)
    b:SetSize(46, 38)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp")
    b.hover = W.Fill(b, "hover")
    b.hover:SetAllPoints()
    b.hover:Hide()
    b.sel = W.Fill(b, "selected")
    b.sel:SetAllPoints()
    b.sel:Hide()
    b.bar = W.Fill(b, "accent", "ARTWORK")
    b.bar:SetPoint("TOPLEFT", 0, -4)
    b.bar:SetPoint("BOTTOMLEFT", 0, 4)
    b.bar:SetWidth(2)
    b.bar:Hide()

    local tile = CreateFrame("Frame", nil, b)
    tile:SetSize(28, 28)
    tile:SetPoint("CENTER")
    tile.bg = W.Fill(tile, "panelAlt")
    tile.bg:SetAllPoints()
    W.Outline(tile, "black")
    b.tile = tile
    b.icon = tile:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
    b.initials = W.Text(tile, "bold", "bn")
    b.initials:SetPoint("CENTER", 0, 1)
    b.bnLine = W.Fill(tile, "bn", "ARTWORK", 2)
    b.bnLine:SetPoint("BOTTOMLEFT")
    b.bnLine:SetPoint("BOTTOMRIGHT")
    b.bnLine:SetHeight(2)
    b.bnLine:SetAlpha(0.55)

    -- Unread pill with a ring in the rail colour so it reads cut out.
    b.ring = W.Pill(b, 19, "sidebar", "OVERLAY")
    b.pill = W.Pill(b, 15, "accent", "OVERLAY")
    b.pill:SetPoint("TOPRIGHT", b, "TOPRIGHT", -3, -2)
    b.ring:SetPoint("CENTER", b.pill, "CENTER")
    b.ring:SetFrameLevel(b:GetFrameLevel() + 2)
    b.pill:SetFrameLevel(b:GetFrameLevel() + 3)
    b.count = W.Text(b.pill, "badge", "onAccent")
    b.count:SetPoint("CENTER", 0, 0)

    b:SetScript("OnEnter", function(self)
        if not self.active then self.hover:Show() end
        showTip(self)
    end)
    b:SetScript("OnLeave", function(self)
        self.hover:Hide()
        W.HideTip(self)
    end)
    b:SetScript("OnClick", function(self, button)
        if not self.conv then return end
        if button == "RightButton" then
            convMenu(self)
        elseif button == "MiddleButton" then
            ns.Store.Close(self.conv)
        else
            ns.UI.Open(self.conv)
        end
    end)
    return b
end

local function paintBadge(b, conv, active)
    b.conv = conv
    b.active = active
    b.sel:SetShown(active)
    b.bar:SetShown(active)
    local icon = ns.Contacts.Icon(conv)
    if icon then
        if icon.atlas then
            b.icon:SetAtlas(icon.atlas)
        else
            b.icon:SetTexture(icon.texture)
            b.icon:SetTexCoord(icon.coords[1], icon.coords[2], icon.coords[3], icon.coords[4])
        end
        b.icon:Show()
        b.initials:Hide()
        b.bnLine:Hide()
    else
        b.icon:Hide()
        b.initials:SetText(ns.Contacts.Initials(conv))
        W.SetTextColor(b.initials, conv.kind == "bn" and "bn" or "dim")
        b.initials:Show()
        b.bnLine:SetShown(conv.kind == "bn")
    end
    local offline = conv.online == false
    b.tile:SetAlpha(offline and 0.45 or 1)
    b.icon:SetDesaturated(offline)
    local unread = conv.unread or 0
    if unread > 0 then
        b.count:SetText(unread > 9 and "9+" or tostring(unread))
        local w = max(15, floor(b.count:GetStringWidth() + 9))
        b.pill:SetWidth(w)
        b.ring:SetWidth(w + 4)
        b.pill:Show()
        b.ring:Show()
    else
        b.pill:Hide()
        b.ring:Hide()
    end
end

-------------------------------------------------------------------------------
--  Build and refresh
-------------------------------------------------------------------------------
function R.Build(rail)
    R.frame = rail

    local mark = CreateFrame("Button", nil, rail)
    mark:SetSize(46, 40)
    mark:SetPoint("TOP")
    mark.icon = W.Icon(mark, W.MEDIA .. "mark", 18, "accent")
    mark.icon:SetPoint("CENTER", 0, 0)
    mark:RegisterForDrag("LeftButton")
    mark:SetScript("OnDragStart", function() ns.UI.StartMoving() end)
    mark:SetScript("OnDragStop", function() ns.UI.StopMoving() end)
    mark:SetScript("OnEnter", function(self) W.Tip(self, "Sotto", { L["Drag to move"] }, "ANCHOR_RIGHT") end)
    mark:SetScript("OnLeave", function(self) W.HideTip(self) end)
    R.mark = mark

    local sep = W.Fill(rail, "hair", "BORDER")
    sep:SetPoint("TOPLEFT", 9, -40)
    sep:SetPoint("TOPRIGHT", -9, -40)
    W.Paint(sep, function(t) t:SetHeight(W.Pixel(rail)) end)

    list = CreateFrame("Frame", nil, rail)
    list:SetPoint("TOPLEFT", 0, -45)
    list:SetPoint("BOTTOMRIGHT", 0, 62)
    list:SetClipsChildren(true)
    list:EnableMouseWheel(true)
    list:SetScript("OnMouseWheel", function(_, delta)
        offset = offset - delta
        R.Refresh()
    end)
    R.list = list

    R.gear = W.IconButton(rail, "gear", L["Settings"], function()
        if ns.UI.View() == "settings" then ns.UI.Show() else ns.UI.ShowSettings() end
    end, nil, 15)
    R.gear:SetSize(30, 26)
    R.gear:SetPoint("BOTTOM", 0, 6)
    R.gear.restColor = "muted"
    W.SetIconColor(R.gear.icon, "muted")

    R.plus = W.IconButton(rail, "plus", L["New conversation"], function() ns.UI.NewConversation() end, nil, 15)
    R.plus:SetSize(30, 26)
    R.plus:SetPoint("BOTTOM", R.gear, "TOP", 0, 2)
    R.plus.restColor = "muted"
    W.SetIconColor(R.plus.icon, "muted")
end

function R.Refresh()
    if not list then return end
    for _, b in ipairs(R.badges) do
        b:Hide()
        pool[#pool + 1] = b
    end
    R.badges = {}
    local convs = ns.Store.List()
    local fits = max(1, floor((list:GetHeight() + 2) / ROW))
    offset = max(0, min(offset, #convs - fits))
    local active = ns.UI.Active and ns.UI.Active()
    for i = offset + 1, min(#convs, offset + fits) do
        local b = table.remove(pool) or newBadge()
        b:ClearAllPoints()
        b:SetPoint("TOP", list, "TOP", 0, -((i - offset - 1) * ROW))
        paintBadge(b, convs[i], convs[i] == active)
        b:Show()
        R.badges[#R.badges + 1] = b
    end
    local settings = ns.UI.View and ns.UI.View() == "settings"
    R.gear.activeColor = settings and "accent" or nil
    W.SetIconColor(R.gear.icon, settings and "accent" or "muted")
end

ns.Listen("LOOKS_CHANGED", function() R.Refresh() end)
