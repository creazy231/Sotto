local T = T

-- Sotto never writes to Blizzard's chat box: the reply keys come to Sotto
-- through override bindings, set out of combat and outside instances.

local function load(setup)
    local G, W, ns = T.load({ setup = setup })
    return G, W, ns
end

local function box(G) return G.ChatFrame1EditBox end

T.it("the reply keys are bound to Sotto while the setting is on", function()
    local G, W, ns = load()
    T.eq(W.overrides["R"], "SOTTO_REPLY")
    T.eq(W.overrides["SHIFT-R"], "SOTTO_REPLY_SENT")
end)

T.it("turning the setting off gives the keys back", function()
    local G, W, ns = load()
    ns.Set("intercept", false)
    T.eq(next(W.overrides), nil)
    ns.Set("intercept", true)
    T.eq(W.overrides["R"], "SOTTO_REPLY")
end)

T.it("in an instance the reply keys stay with Blizzard", function()
    local G, W, ns = load()
    W.instance = true
    W.fire("PLAYER_ENTERING_WORLD", false, false)
    T.eq(next(W.overrides), nil, "Blizzard's reply works with secret names")
    W.instance = false
    W.fire("ZONE_CHANGED_NEW_AREA")
    T.eq(W.overrides["R"], "SOTTO_REPLY")
end)

T.it("binding changes in combat wait for combat to end", function()
    local G, W, ns = load()
    W.combat = true
    ns.Set("intercept", false)
    T.eq(W.overrides["R"], "SOTTO_REPLY", "untouched in combat")
    W.combat = false
    W.fire("PLAYER_REGEN_ENABLED")
    T.eq(next(W.overrides), nil, "applied after combat")
end)

T.it("changed key bindings are picked up", function()
    local G, W, ns = load()
    W.bindings.REPLY = { "T" }
    W.fire("UPDATE_BINDINGS")
    T.eq(W.overrides["T"], "SOTTO_REPLY")
    T.eq(W.overrides["R"], nil)
end)

T.it("Sotto never touches Blizzard's chat box", function()
    local G, W, ns = load()
    G.ChatFrameUtil.SendTell("Tarin Ashgrove")
    W.advance(0)
    T.ok(box(G):IsShown(), "Blizzard's box stays open")
    T.eq(box(G):GetAttribute("chatType"), "WHISPER")
    T.eq(box(G):GetAttribute("tellTarget"), "Tarin Ashgrove")
    T.eq(W.focus, box(G), "focus stays in Blizzard's box")
    T.no(ns.UI.IsShown(), "Sotto waits until the whisper is sent")
end)

T.it("a typed /r to a stale target prints a notice", function()
    local G, W, ns = load()
    G.ChatFrameUtil.SetLastTellTarget("Old Friend", "WHISPER")
    W.chat("CHAT_MSG_WHISPER", W.whisperArgs("hey", "Aaa"))
    local before = #W.chatLog
    box(G):ProcessChatType("hi", "REPLY", 0)
    W.advance(0)
    local notice = W.chatLog[#W.chatLog]
    T.ok(#W.chatLog > before and type(notice) == "string", "notice printed")
    T.ok(notice:find("Old Friend", 1, true) and notice:find("Aaa", 1, true), notice)
    T.eq(box(G):GetAttribute("tellTarget"), "Old Friend", "the box itself is left alone")
end)

T.it("a typed /r to the right person stays quiet", function()
    local G, W, ns = load()
    G.ChatFrameUtil.SetLastTellTarget("Aaa", "WHISPER")
    W.chat("CHAT_MSG_WHISPER", W.whisperArgs("hey", "Aaa"))
    local before = #W.chatLog
    box(G):ProcessChatType("hi", "REPLY", 0)
    W.advance(0)
    T.eq(#W.chatLog, before)
end)
