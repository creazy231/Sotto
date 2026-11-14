-------------------------------------------------------------------------------
--  Sotto: a small window to copy text from (links, a name, a transcript).
--  The text is selected and focused; Ctrl+C copies, Esc closes. Typing does
--  not change it. It takes the Scale setting, as the window does.
-------------------------------------------------------------------------------
local _, ns = ...
local Cb = {}
ns.CopyBox = Cb

local W, L = ns.W, ns.L
local frame, current

-- 120 above the middle of the screen, in UIParent's units: the offset is in
-- the box's own, which grow with its scale.
local function place()
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 120 / W.Scale())
end

local function build()
    frame = W.Scaled(CreateFrame("Frame", "SottoCopyBox", UIParent))
    frame:SetSize(400, 120)
    place()
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:Hide()
    frame.bg = W.Fill(frame, "panel")
    frame.bg:SetAllPoints()
    W.Border(frame, "hair")
    W.Outline(frame, "edge")
    W.Shadow(frame, 16, 0.55)

    frame.title = W.Text(frame, "title", "text")
    frame.title:SetPoint("TOPLEFT", 14, -12)
    frame.close = W.IconButton(frame, "close", nil, function() frame:Hide() end)
    frame.close:SetPoint("TOPRIGHT", -6, -6)

    local field = CreateFrame("Frame", nil, frame)
    field:SetPoint("TOPLEFT", 12, -38)
    field:SetPoint("BOTTOMRIGHT", -12, 30)
    field.bg = W.Fill(field, "inset")
    field.bg:SetAllPoints()
    W.Border(field, "focus")

    local scroll = CreateFrame("ScrollFrame", nil, field)
    scroll:SetPoint("TOPLEFT", 8, -6)
    scroll:SetPoint("BOTTOMRIGHT", -8, 6)
    local edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetWidth(360)
    scroll:SetScrollChild(edit)
    W.Paint(edit, function(e)
        e:SetFont(ns.Theme.Font("body"))
        e:SetTextColor(ns.Theme.Color("text"))
    end)
    edit:SetScript("OnEscapePressed", function() frame:Hide() end)
    edit:SetScript("OnTextChanged", function(self, user)
        if user and current then
            self:SetText(current)
            self:HighlightText()
        end
    end)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local range = self:GetVerticalScrollRange() or 0
        self:SetVerticalScroll(math.max(0, math.min(range, self:GetVerticalScroll() - delta * 30)))
    end)
    frame.edit = edit
    frame.scroll = scroll

    frame.hint = W.Text(frame, "hint", "faint")
    frame.hint:SetPoint("BOTTOMLEFT", 14, 10)
    frame.hint:SetText(L["Ctrl+C copies · Esc closes"])
    tinsert(UISpecialFrames, "SottoCopyBox")
    Cb.frame = frame
end

function Cb.Show(title, text)
    if not frame then build() end
    current = text or ""
    frame.title:SetText(title or L["Copy"])
    local lines = select(2, current:gsub("\n", "")) + 1
    local long = lines > 1 or #current > 60
    frame:SetHeight(long and 220 or 104)
    frame.edit:SetText(current)
    frame.edit:SetCursorPosition(0)
    frame:Show()
    frame.edit:SetFocus()
    frame.edit:HighlightText()
end

ns.Listen("SCALE_CHANGED", function() if frame then place() end end)
