-------------------------------------------------------------------------------
--  Sotto: ways in. A round minimap button with the unread count (EllesmereUI's
--  minimap gathers named minimap buttons into its flyout), the addon
--  compartment entry, /sotto, and key bindings (Bindings.xml).
-------------------------------------------------------------------------------
local _, ns = ...
local Ln = {}
ns.Launcher = Ln

local W, L = ns.W, ns.L
local floor = math.floor

-------------------------------------------------------------------------------
--  Minimap button
-------------------------------------------------------------------------------
local b = CreateFrame("Button", "SottoMinimapButton", Minimap)
b:SetSize(32, 32)
b:SetFrameStrata("MEDIUM")
b:SetFrameLevel(8)
b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
b:RegisterForDrag("LeftButton")
b.disc = b:CreateTexture(nil, "BACKGROUND")
b.disc:SetTexture(W.MEDIA .. "minimap")
b.disc:SetAllPoints()
b.icon = W.Icon(b, W.MEDIA .. "mark", 18, "accent")
b.icon:SetPoint("CENTER", 0, 0)
b.hl = b:CreateTexture(nil, "HIGHLIGHT")
b.hl:SetTexture(W.MEDIA .. "circle")
b.hl:SetAllPoints()
b.hl:SetVertexColor(1, 1, 1, 0.1)
b.ring = W.Pill(b, 18, "sidebar", "OVERLAY")
b.pill = W.Pill(b, 14, "accent", "OVERLAY")
b.pill:SetPoint("TOPRIGHT", b, "TOPRIGHT", 3, 2)
b.ring:SetPoint("CENTER", b.pill, "CENTER")
b.ring:SetFrameLevel(b:GetFrameLevel() + 2)
b.pill:SetFrameLevel(b:GetFrameLevel() + 3)
b.count = W.Text(b.pill, "badge", "onAccent")
b.count:SetPoint("CENTER")
b.pill:Hide()
b.ring:Hide()
Ln.button = b

local function place()
    local angle = math.rad((ns.DB and ns.DB.minimapAngle) or 215)
    local r = (Minimap:GetWidth() / 2) + 6
    b:ClearAllPoints()
    b:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * r, math.sin(angle) * r)
end

local function tooltip(owner, anchor)
    local n = ns.Store.UnreadTotal()
    local line = n == 1 and L["1 unread whisper"] or (n > 1 and string.format(L["%d unread whispers"], n))
        or L["No unread whispers"]
    W.Tip(owner, "Sotto", { line, { L["Click: open · Right-click: settings"], 0.44, 0.45, 0.47 } }, anchor)
end

b:SetScript("OnClick", function(_, button)
    if button == "RightButton" then ns.UI.ShowSettings() else ns.UI.Toggle() end
end)
b:SetScript("OnEnter", function(self) tooltip(self, "ANCHOR_LEFT") end)
b:SetScript("OnLeave", function(self) W.HideTip(self) end)
b:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function()
        local mx, my = Minimap:GetCenter()
        local cx, cy = GetCursorPosition()
        local s = Minimap:GetEffectiveScale()
        if not mx or not s or s <= 0 then return end
        ns.DB.minimapAngle = math.deg(math.atan2(cy / s - my, cx / s - mx))
        place()
    end)
end)
b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)

function Ln.Update()
    local n = ns.Store.UnreadTotal()
    if n > 0 then
        b.count:SetText(n > 9 and "9+" or tostring(n))
        local w = math.max(14, floor(b.count:GetStringWidth() + 8))
        b.pill:SetWidth(w)
        b.ring:SetWidth(w + 4)
        b.pill:Show()
        b.ring:Show()
    else
        b.pill:Hide()
        b.ring:Hide()
    end
end

-- Shown or hidden only here (login, setting): EllesmereUI's minimap hides
-- the buttons it collects and must not see them shown again on every whisper.
function Ln.ApplyVisibility()
    if ns.Get("minimap") then b:Show() else b:Hide() end
end

ns.Listen("UNREAD_CHANGED", Ln.Update)
ns.Listen("CONV_UPDATED", Ln.Update)
ns.Listen("SETTING_CHANGED", function(key) if key == "minimap" then Ln.ApplyVisibility() end end)
ns.On("PLAYER_LOGIN", function()
    place()
    Ln.Update()
    Ln.ApplyVisibility()
end)

-------------------------------------------------------------------------------
--  Addon compartment (TOC: AddonCompartmentFunc*)
-------------------------------------------------------------------------------
function Sotto_OnAddonCompartmentClick(_, button)
    if button == "RightButton" then ns.UI.ShowSettings() else ns.UI.Toggle() end
end

function Sotto_OnAddonCompartmentEnter(_, frame)
    if frame then tooltip(frame, "ANCHOR_LEFT") end
end

function Sotto_OnAddonCompartmentLeave()
    GameTooltip:Hide()
end

-------------------------------------------------------------------------------
--  Slash command and key bindings
-------------------------------------------------------------------------------
SLASH_SOTTO1 = "/sotto"
SlashCmdList.SOTTO = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")
    if msg == "" then
        ns.UI.Toggle()
    elseif msg == "settings" or msg == "options" or msg == "config" then
        ns.UI.ShowSettings()
    elseif msg == "reset" then
        ns.UI.ResetGeometry()
        ns.Print(L["The window is back in its first place."])
    else
        ns.Print(L["/sotto opens or closes the window · /sotto settings · /sotto reset"])
    end
end

BINDING_HEADER_SOTTO = "Sotto"
BINDING_NAME_SOTTO_TOGGLE = L["Show or hide Sotto"]
BINDING_NAME_SOTTO_REPLY = L["Reply to the last whisper"]
BINDING_NAME_SOTTO_NEXT = L["Next unread conversation"]
BINDING_NAME_SOTTO_REPLY_SENT = L["Whisper the last person you whispered"]

function Sotto_BindingToggle() ns.UI.Toggle() end

function Sotto_BindingReply()
    local conv = ns.Engine.LastIncoming()
    if conv then ns.UI.Open(conv, { focus = true }) else ns.UI.Show() end
end

function Sotto_BindingReplySent()
    local conv = ns.Engine.LastOutgoing()
    if conv then ns.UI.Open(conv, { focus = true }) else ns.UI.Show() end
end

function Sotto_BindingNext() ns.UI.SelectNextUnread() end
