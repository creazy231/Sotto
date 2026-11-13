local T = T

-- Retail and every Classic client run the same chat, menu and Battle.net code
-- as WoW Forever (wow-ui-source branches live, classic, classic_anniversary,
-- classic_era, classic_titan and forever, 2026-11-13). What differs for Sotto:
-- names are "Name-Realm" instead of first name and surname, and Battle.net
-- friends are never whispered by character (no
-- C_BattleNet.GetDefaultTitleWhisperTarget there).

local function otherClient(G, W)
    W.run = false
    W.player.name, W.player.realm = "Kelra", "Silvermoon"
    G.C_BattleNet.GetDefaultTitleWhisperTarget = nil
end

local function load(extra)
    local G, W, ns = T.load({ setup = function(G, W)
        otherClient(G, W)
        if extra then extra(G, W) end
    end })
    return G, W, ns
end

local function whisper(W, text, sender, o)
    W.chat("CHAT_MSG_WHISPER", W.whisperArgs(text, sender, o))
end

T.it("a whisper from your own realm is one conversation, with or without the realm", function()
    local G, W, ns = load()
    ns.Set("openOn", "never")
    whisper(W, "hi", "Bob-Silvermoon")
    whisper(W, "still there?", "Bob")
    local c = ns.Store.Get(ns.Names.Key("Bob"))
    T.ok(c, "conversation")
    T.eq(c.name, "Bob")
    T.eq(#c.msgs, 2)
    T.eq(#ns.Store.List(), 1)
end)

T.it("a whisper from another realm keeps the realm, and the answer goes there", function()
    local G, W, ns = load()
    whisper(W, "lf tank?", "Kim-TwistingNether")
    local c = ns.Store.Get(ns.Names.Key("Kim-TwistingNether"))
    T.ok(c, "conversation")
    T.eq(c.name, "Kim-TwistingNether")
    T.no(ns.Store.Get(ns.Names.Key("Kim")), "not the Kim of your own realm")
    T.ok(ns.Engine.Send(c, "sure"), "sent")
    T.eq(W.sent[1].chatType, "WHISPER")
    T.eq(W.sent[1].target, "Kim-TwistingNether")
end)

T.it("Whisper in the menu of a player from another realm opens that conversation", function()
    local G, W, ns = load()
    local menu = G.UnitPopup_OpenMenu("FRIEND", { name = "Kim-TwistingNether", chatFrame = G.ChatFrame1 })
    W.menuItem(menu, "Whisper"):Pick()
    local c = ns.UI.Active()
    T.ok(c, "conversation open")
    T.eq(c.key, ns.Names.Key("Kim-TwistingNether"))
    T.eq(c.name, "Kim-TwistingNether")
    T.eq(W.focus, ns.Compose.box, "ready to type")
    T.eq(#W.menuWhispers, 0, "Blizzard's whisper did not run")
end)

T.it("a Battle.net friend always gets a Battle.net conversation", function()
    local G, W, ns = load(function(G, W)
        W.bnFriends = { { bnetAccountID = 9, accountName = "|Kq9|k", battleTag = "Robin#4321",
            gameAccountInfo = { isOnline = true, clientProgram = "WoW", characterName = "Robin" } } }
    end)
    ns.Set("openOn", "never")
    W.chat("CHAT_MSG_BN_WHISPER", W.whisperArgs("hey", "|Kq9|k", { bnID = 9 }))
    local c = ns.Store.Get("bn:robin#4321")
    T.ok(c, "Battle.net conversation")
    T.eq(#c.msgs, 1)
    local menu = G.UnitPopup_OpenMenu("BN_FRIEND", { name = "|Kq9|k", bnetIDAccount = 9 })
    W.menuItem(menu, "Whisper"):Pick()
    T.eq(ns.UI.Active(), c, "the menu opens the same conversation")
end)

T.it("without the surname API a hyphen starts the realm", function()
    local G, W, ns = load(function(G) G.RegionalUniqueNamesEnabled = nil end)
    local N = ns.Names
    T.eq(N.Key("Bob-Silvermoon"), N.Key("Bob"), "own realm dropped")
    T.ok(N.Key("Bob-Other") ~= N.Key("Bob Other"), "a realm, not a surname")
    T.eq(N.Display("Bob-Other"), "Bob-Other")
end)
