local T = T

-- Core only: a stand-in UI records what Sotto was asked to open.
local function load(setup)
    local G, W, ns = T.load({ setup = setup })
    ns.Set("openOn", "never") -- only interception may open Sotto in these tests
    local opened = {}
    ns.UI = ns.UI or {}
    ns.UI.Open = function(conv, opts) opened[#opened + 1] = { conv = conv, opts = opts or {} } end
    ns.UI.IsShown = function() return false end
    return G, W, ns, opened
end

local function box(G) return G.ChatFrame1EditBox end

T.it("a whisper header opens Sotto one frame later and closes the chat box", function()
    local G, W, ns, opened = load()
    G.ChatFrameUtil.SendTell("Tarin Ashgrove")
    T.eq(#opened, 0, "not inside Blizzard's call")
    W.advance(0)
    T.eq(#opened, 1)
    T.eq(opened[1].conv.key, "tarin ashgrove")
    T.eq(opened[1].opts.focus, true)
    T.no(box(G):IsShown(), "chat box closed")
    T.eq(box(G):GetAttribute("chatType"), "SAY", "back to SAY")
    T.eq(box(G):GetAttribute("tellTarget"), nil)
end)

T.it("typed text is carried over", function()
    local G, W, ns, opened = load()
    G.ChatFrameUtil.SendTellWithMessage("Tarin Ashgrove", "hello there")
    W.advance(0)
    T.eq(opened[1].opts.text, "hello there")
end)

T.it("nothing happens in combat", function()
    local G, W, ns, opened = load()
    W.combat = true
    G.ChatFrameUtil.SendTell("Tarin Ashgrove")
    W.advance(0)
    T.eq(#opened, 0)
    T.ok(box(G):IsShown(), "Blizzard keeps the whisper")
    T.eq(box(G):GetAttribute("chatType"), "WHISPER")
end)

T.it("nothing happens in chat lockdown", function()
    local G, W, ns, opened = load()
    W.lockdown = true
    G.ChatFrameUtil.SendTell("Tarin Ashgrove")
    W.advance(0)
    T.eq(#opened, 0)
end)

T.it("a secret target is left to Blizzard", function()
    local G, W, ns, opened = load()
    local b = box(G)
    G.ChatFrameUtil.ActivateChat(b)
    b:SetAttribute("chatType", "BN_WHISPER")
    b:SetAttribute("tellTarget", T.secret("|Kq5|k"))
    b:UpdateHeader()
    W.advance(0)
    T.eq(#opened, 0)
end)

T.it("nothing happens with the setting off", function()
    local G, W, ns, opened = load()
    ns.Set("intercept", false)
    G.ChatFrameUtil.SendTell("Tarin Ashgrove")
    W.advance(0)
    T.eq(#opened, 0)
end)

T.it("ReplyTell opens Sotto's last incoming conversation", function()
    local G, W, ns, opened = load()
    W.chat("CHAT_MSG_WHISPER", W.whisperArgs("hey", "Aaa"))
    G.ChatFrameUtil.ReplyTell(G.ChatFrame1)
    W.advance(0)
    T.eq(#opened, 1)
    T.eq(opened[1].conv.key, "aaa")
    T.eq(opened[1].opts.focus, true)
end)

T.it("ReplyTell with a stale Blizzard target still opens the right conversation", function()
    local G, W, ns, opened = load()
    G.ChatFrameUtil.SetLastTellTarget("Old Friend", "WHISPER")
    W.chat("CHAT_MSG_WHISPER", W.whisperArgs("hey", "Aaa"))
    G.ChatFrameUtil.ReplyTell(G.ChatFrame1)
    W.advance(0)
    T.eq(#opened, 1)
    T.eq(opened[1].conv.key, "aaa")
    T.no(box(G):IsShown(), "stale whisper box closed")
end)

T.it("ReplyTell2 opens the last outgoing conversation", function()
    local G, W, ns, opened = load()
    W.chat("CHAT_MSG_WHISPER", W.whisperArgs("hey", "Aaa"))
    W.chat("CHAT_MSG_WHISPER_INFORM", W.whisperArgs("yo", "Bbb"))
    G.ChatFrameUtil.ReplyTell2(G.ChatFrame1)
    W.advance(0)
    T.eq(opened[1].conv.key, "bbb")
end)

T.it("a Battle.net header opens the Battle.net conversation", function()
    local G, W, ns, opened = load(function(G, W)
        W.bnFriends = { { bnetAccountID = 5, accountName = "|Kq5|k", battleTag = "Alex#1234",
            gameAccountInfo = { isOnline = true, clientProgram = "App" } } }
    end)
    G.ChatFrameUtil.SendBNetTell("|Kq5|k")
    W.advance(0)
    T.eq(#opened, 1)
    T.eq(opened[1].conv.key, "bn:alex#1234")
end)

T.it("edit boxes activated later get hooked too", function()
    local G, W, ns, opened = load()
    local b = G.CreateFrame("EditBox", "ChatFrame5EditBox", G.UIParent)
    function b:UpdateHeader() end
    function b:ClearChat() self:SetText(""); self:Hide() end
    G.ChatFrameUtil.ActivateChat(b)
    b:SetAttribute("chatType", "WHISPER")
    b:SetAttribute("tellTarget", "Kaja Stormhoof")
    b:UpdateHeader()
    W.advance(0)
    T.eq(#opened, 1)
    T.eq(opened[1].conv.key, "kaja stormhoof")
end)
