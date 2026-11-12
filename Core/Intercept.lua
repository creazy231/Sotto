-------------------------------------------------------------------------------
--  Sotto: whispers the player starts (/w Name, the reply keys, "Whisper" in
--  menus, Battle.net tells) open the conversation in Sotto.
--
--  Post-hooks only (hooksecurefunc): each chat edit box's UpdateHeader
--  (hooked when the box is first activated and at login) and
--  ChatFrameUtil.ReplyTell / ReplyTell2. Nothing happens inside Blizzard's
--  call: the hooks note what they saw and Sotto acts one frame later, after
--  ReplyTell/SendTell/OpenChat have finished. Then, only out of combat, out of
--  chat lockdown and with readable values, the box is set back to SAY and
--  closed with its own escape handler (secure slash commands run in ParseText
--  before the chat type is read, so they are unaffected).
--
--  Reply targets: a whisper Sotto hid never reaches Blizzard's
--  SetLastTellTarget, so Blizzard's reply target goes stale. A reply key
--  therefore always opens Sotto's own last incoming (ReplyTell) or outgoing
--  (ReplyTell2) conversation. Sotto never writes Blizzard's last-tell list.
-------------------------------------------------------------------------------
local _, ns = ...
local I = {}
ns.Intercept = I

local hooked = setmetatable({}, { __mode = "k" })
local pending
local scheduled = false

local function enabled()
    return ns.DB ~= nil and ns.Get("intercept") and not InCombatLockdown() and not ns.InLockdown()
end

local function isWhisper(chatType)
    return chatType == "WHISPER" or chatType == "BN_WHISPER"
end

local function resolve(chatType, target)
    if chatType == "WHISPER" then return ns.Store.Ensure("w", target) end
    local bnID = BNet_GetBNetIDAccount and BNet_GetBNetIDAccount(target)
    if ns.IsSecret(bnID) or type(bnID) ~= "number" then return nil end
    local tag
    local info = C_BattleNet and C_BattleNet.GetAccountInfoByID and C_BattleNet.GetAccountInfoByID(bnID)
    if type(info) == "table" and not ns.IsSecret(info.battleTag) then tag = info.battleTag end
    return ns.Store.Ensure("bn", target, { tag = tag, bnID = bnID })
end

local function closeBox(box)
    local chatType = box:GetAttribute("chatType")
    if not ns.IsSecret(chatType) and isWhisper(chatType) then
        box:SetAttribute("chatType", "SAY")
        box:SetAttribute("tellTarget", nil)
    end
    local sticky = box:GetAttribute("stickyType")
    if not ns.IsSecret(sticky) and isWhisper(sticky) then box:SetAttribute("stickyType", "SAY") end
    local escape = (ChatFrameEditBoxMixin and ChatFrameEditBoxMixin.OnEscapePressed) or ChatEdit_OnEscapePressed
    if not (escape and pcall(escape, box)) then
        box:SetText("")
        box:Hide()
    end
end

local function flush()
    scheduled = false
    local p = pending
    pending = nil
    if not p or not enabled() or not (ns.UI and ns.UI.Open) then return end

    local box = p.box
    if not box and ChatFrameUtil and ChatFrameUtil.GetActiveWindow then box = ChatFrameUtil.GetActiveWindow() end
    local chatType, target, boxWhisper
    if box and box:IsShown() then
        chatType, target = box:GetAttribute("chatType"), box:GetAttribute("tellTarget")
        -- A secret target (Battle.net in some 12.x states) stays with Blizzard.
        if ns.IsSecret(chatType, target) then return end
        boxWhisper = isWhisper(chatType) and type(target) == "string" and target ~= ""
    end

    local conv
    if p.reply == "out" then conv = ns.Engine.LastOutgoing() end
    if p.reply == "in" then conv = ns.Engine.LastIncoming() end
    if not conv and boxWhisper then conv = resolve(chatType, target) end
    if not conv then return end

    local text
    if boxWhisper then
        text = box:GetText()
        if ns.IsSecret(text) or type(text) ~= "string" or text == "" then text = nil end
        closeBox(box)
    end
    ns.UI.Open(conv, { focus = true, text = text })
end

local function schedule()
    if scheduled then return end
    scheduled = true
    C_Timer.After(0, flush)
end

local function onHeader(box)
    if not enabled() then return end
    local chatType = box:GetAttribute("chatType")
    if ns.IsSecret(chatType) or not isWhisper(chatType) then return end
    pending = pending or {}
    pending.box = box
    schedule()
end

local function onReply(which)
    if not enabled() then return end
    pending = pending or {}
    pending.reply = which
    schedule()
end

function I.HookEditBox(box)
    if not box or hooked[box] or type(box.UpdateHeader) ~= "function" then return end
    hooked[box] = true
    hooksecurefunc(box, "UpdateHeader", onHeader)
end

function I.Init()
    local CFU = ChatFrameUtil
    if CFU and CFU.ActivateChat then
        hooksecurefunc(CFU, "ActivateChat", function(box) I.HookEditBox(box) end)
        if CFU.ReplyTell then hooksecurefunc(CFU, "ReplyTell", function() onReply("in") end) end
        if CFU.ReplyTell2 then hooksecurefunc(CFU, "ReplyTell2", function() onReply("out") end) end
    else
        -- Older chat code without ChatFrameUtil.
        if ChatEdit_UpdateHeader then hooksecurefunc("ChatEdit_UpdateHeader", onHeader) end
        if ChatFrame_ReplyTell then hooksecurefunc("ChatFrame_ReplyTell", function() onReply("in") end) end
        if ChatFrame_ReplyTell2 then hooksecurefunc("ChatFrame_ReplyTell2", function() onReply("out") end) end
    end
    for i = 1, (NUM_CHAT_WINDOWS or 10) do
        I.HookEditBox(_G["ChatFrame" .. i .. "EditBox"])
    end
end

ns.On("PLAYER_LOGIN", function() I.Init() end)
