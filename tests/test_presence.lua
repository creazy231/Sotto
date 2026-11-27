local T = T

-- A friend who comes online or goes offline while their conversation is on screen
-- gets a line there, as in WIM 3.19.8. The chat window keeps its own notice.

local function whisper(W, text, sender, o)
    W.chat("CHAT_MSG_WHISPER", W.whisperArgs(text, sender, o))
end

local function shownInChat(W, text)
    for _, e in ipairs(W.chatLog) do
        if type(e) == "table" and e.text == text then return true end
    end
    return false
end

local function alex(G, W)
    W.bnFriends = { { bnetAccountID = 5, accountName = "|Kq5|k", battleTag = "Alex#1234",
        gameAccountInfo = { isOnline = true, clientProgram = "App" } } }
end

local function offline(G, W, name) W.chat("CHAT_MSG_SYSTEM", G.ERR_FRIEND_OFFLINE_S:format(name)) end
local function online(G, W, name) W.chat("CHAT_MSG_SYSTEM", G.ERR_FRIEND_ONLINE_SS:format(name, name)) end

T.it("a friend whose conversation is on screen gets a line on going offline and on coming back", function()
    local G, W, ns = T.load()
    whisper(W, "brb", "Tarin Ashgrove")
    local c = ns.Store.Get("tarin ashgrove")
    offline(G, W, "Tarin Ashgrove")
    local m = c.msgs[#c.msgs]
    T.eq(m.d, "s")
    T.eq(m.s, "offline")
    T.eq(m.m, "Tarin went offline")
    T.eq(c.online, false)
    T.ok(shownInChat(W, G.ERR_FRIEND_OFFLINE_S:format("Tarin Ashgrove")), "the chat window keeps its notice")
    W.clock = W.clock + 300
    online(G, W, "Tarin Ashgrove")
    m = c.msgs[#c.msgs]
    T.eq(m.s, "online")
    T.eq(m.m, "Tarin came online")
    T.eq(c.online, true)
end)

T.it("a conversation not on screen only changes its state", function()
    local G, W, ns = T.load()
    whisper(W, "brb", "Tarin Ashgrove")
    ns.UI.Hide()
    local c = ns.Store.Get("tarin ashgrove")
    local n = #c.msgs
    offline(G, W, "Tarin Ashgrove")
    T.eq(#c.msgs, n, "no line")
    T.eq(c.online, false, "the state still changes")
end)

T.it("the same notice twice within a minute adds one line", function()
    local G, W, ns = T.load()
    whisper(W, "brb", "Tarin Ashgrove")
    local c = ns.Store.Get("tarin ashgrove")
    offline(G, W, "Tarin Ashgrove")
    local n = #c.msgs
    W.clock = W.clock + 20
    offline(G, W, "Tarin Ashgrove")
    T.eq(#c.msgs, n)
    W.clock = W.clock + 60
    offline(G, W, "Tarin Ashgrove")
    T.eq(#c.msgs, n + 1, "a minute later it is news again")
end)

T.it("a Battle.net friend whose conversation is on screen gets the line too", function()
    local G, W, ns = T.load({ setup = alex })
    local c = ns.Store.Ensure("bn", "|Kq5|k", { tag = "Alex#1234", bnID = 5 })
    ns.UI.Open(c)
    W.chat("CHAT_MSG_BN_INLINE_TOAST_ALERT", W.whisperArgs("FRIEND_OFFLINE", "|Kq5|k", { bnID = 5 }))
    local m = c.msgs[#c.msgs]
    T.ok(m, "a line")
    T.eq(m.m, "Alex went offline")
    T.eq(c.online, false)
end)

T.it("with separate windows a shown window's conversation gets the line", function()
    local G, W, ns = T.load()
    ns.Set("separate", true)
    whisper(W, "brb", "Tarin Ashgrove")
    local c = ns.Store.Get("tarin ashgrove")
    offline(G, W, "Tarin Ashgrove")
    T.eq(c.msgs[#c.msgs].m, "Tarin went offline")
end)

-- After the fresh-eyes review.

T.it("a line leaves the rail's order alone", function()
    local G, W, ns = T.load()
    whisper(W, "brb", "Tarin Ashgrove")
    W.clock = W.clock + 60
    whisper(W, "hi", "Bbb")
    T.eq(ns.Store.List()[1], ns.Store.Get("bbb"))
    W.clock = W.clock + 60
    offline(G, W, "Tarin Ashgrove") -- the window still shows Tarin
    T.eq(ns.Store.Get("tarin ashgrove").msgs[#ns.Store.Get("tarin ashgrove").msgs].s, "offline")
    T.eq(ns.Store.List()[1], ns.Store.Get("bbb"), "Bbb is still the newest")
end)

T.it("a Battle.net friend without a readable BattleTag is named by their account name", function()
    local G, W, ns = T.load({ setup = function(G, W)
        W.bnFriends = { { bnetAccountID = 6, accountName = "|Kq6|k", battleTag = "",
            gameAccountInfo = { isOnline = true, clientProgram = "App" } } }
    end })
    local c = ns.Store.Ensure("bn", "|Kq6|k", { bnID = 6 })
    ns.UI.Open(c)
    W.chat("CHAT_MSG_BN_INLINE_TOAST_ALERT", W.whisperArgs("FRIEND_ONLINE", "|Kq6|k", { bnID = 6 }))
    T.eq(c.msgs[#c.msgs].m, "|Kq6|k came online")
end)

T.it("a friend WoW Forever whispers by character gets the line in that character's conversation", function()
    local G, W, ns = T.load({ setup = function(G, W)
        W.bnFriends = { { bnetAccountID = 8, accountName = "|Kq8|k", battleTag = "", titleTarget = "Kaela Dawnmere",
            gameAccountInfo = { isOnline = true, clientProgram = "WoW", characterName = "Kaela Dawnmere" } } }
    end })
    W.chat("CHAT_MSG_BN_WHISPER", W.whisperArgs("hi", "|Kq8|k", { bnID = 8 }))
    local c = ns.Store.Get("kaela dawnmere")
    T.ok(c and ns.UI.Sees(c), "her character's conversation is on screen")
    W.bnFriends[1].titleTarget = nil -- offline, the game names no character any more
    W.chat("CHAT_MSG_BN_INLINE_TOAST_ALERT", W.whisperArgs("FRIEND_OFFLINE", "|Kq8|k", { bnID = 8 }))
    T.eq(c.msgs[#c.msgs].m, "Kaela went offline")
    T.eq(c.online, false)
end)
