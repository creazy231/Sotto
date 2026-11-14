local T = T

-- "Whisper" in a player menu opens Sotto right away, like WIM, without ever
-- opening (and so without having to close) Blizzard's chat box.

local function load(setup)
    local G, W, ns = T.load({ setup = setup })
    return G, W, ns, ns.UI
end

local function box(G) return G.ChatFrame1EditBox end

local function party(G, W)
    W.units = { party1 = { name = "Kaela Dawnmere", guid = "Player-2-0002", class = "Mage", classFile = "MAGE" } }
    W.guids["Player-2-0002"] = { classLoc = "Mage", classFile = "MAGE", raceLoc = "Undead", raceFile = "Scourge",
        name = "Kaela Dawnmere" }
end

local function bnFriend(G, W)
    W.bnFriends = { { bnetAccountID = 77, accountName = "|Kq77|k", battleTag = "Sunny#1234",
        gameAccountInfo = { isOnline = true, clientProgram = "BSAp" } } }
end

-- WoW Forever: a friend the game whispers by character (C_BattleNet.GetDefaultTitleWhisperTarget).
local function titleFriend(G, W)
    W.bnFriends = { { bnetAccountID = 78, accountName = "|Kq78|k", battleTag = "", titleTarget = "Kaela Dawnmere",
        gameAccountInfo = { isOnline = true, clientProgram = "WoW", characterName = "Kaela Dawnmere" } } }
end

T.it("Whisper on a name in chat opens Sotto, ready to type", function()
    local G, W, ns, UI = load()
    local menu = G.UnitPopup_OpenMenu("FRIEND", { name = "Tarin-Ashgrove", chatFrame = G.ChatFrame1 })
    W.menuItem(menu, "Whisper"):Pick()
    T.ok(UI.IsShown(), "Sotto opens")
    T.eq(UI.Active().key, "tarin ashgrove")
    T.eq(UI.Active().name, "Tarin Ashgrove")
    T.eq(W.focus, ns.Compose.box, "ready to type")
    T.no(box(G):IsShown(), "Blizzard's chat box stays closed")
    T.eq(#W.menuWhispers, 0, "Blizzard's whisper did not run")
end)

T.it("the other entries of the menu stay Blizzard's", function()
    local G, W, ns, UI = load()
    local menu = G.UnitPopup_OpenMenu("FRIEND", { name = "Tarin Ashgrove" })
    W.menuItem(menu, "Invite"):Pick()
    T.eq(W.invited, "Tarin Ashgrove", "Blizzard's invite")
    T.no(UI.IsShown())
    W.menuItem(menu, "Whisper"):Pick()
    T.ok(UI.IsShown(), "only Whisper goes to Sotto")
end)

T.it("Whisper on a unit frame opens the full name, class already known", function()
    local G, W, ns, UI = load(party)
    local menu = G.UnitPopup_OpenMenu("PARTY", { unit = "party1" })
    W.menuItem(menu, "Whisper"):Pick() -- inside the Interact submenu
    local c = UI.Active()
    T.ok(c, "conversation open")
    T.eq(c.key, "kaela dawnmere")
    T.eq(c.name, "Kaela Dawnmere")
    T.eq(c.class, "MAGE", "the badge shows the class from the start")
    T.eq(W.focus, ns.Compose.box)
    T.no(box(G):IsShown())
end)

T.it("Whisper on a Battle.net friend opens their Battle.net conversation", function()
    local G, W, ns, UI = load(bnFriend)
    local menu = G.UnitPopup_OpenMenu("BN_FRIEND", { name = "|Kq77|k", bnetIDAccount = 77 })
    W.menuItem(menu, "Whisper"):Pick()
    local c = UI.Active()
    T.ok(c, "conversation open")
    T.eq(c.kind, "bn")
    T.eq(c.bnID, 77)
    T.eq(c.key, "bn:sunny#1234")
    T.eq(c.online, true, "online, as the friends list shows")
    T.eq(W.focus, ns.Compose.box)
    T.no(box(G):IsShown())
end)

T.it("a Battle.net name link's menu (chat, EllesmereUI's friends list) opens the Battle.net conversation", function()
    local G, W, ns, UI = load(bnFriend)
    -- Blizzard's BNplayer link handler splits the link: the account id arrives as text.
    local menu = G.UnitPopup_OpenMenu("BN_FRIEND", { name = "|Kq77|k", bnetIDAccount = "77" })
    W.menuItem(menu, "Whisper"):Pick()
    local c = UI.Active()
    T.ok(c, "conversation open")
    T.eq(c.kind, "bn", "not a character named after the account token")
    T.eq(c.bnID, 77)
    T.eq(c.key, "bn:sunny#1234")
    T.eq(c.online, true, "online, as the friends list shows")
end)

T.it("a Battle.net friend the game whispers by character opens that character", function()
    local G, W, ns, UI = load(titleFriend)
    local menu = G.UnitPopup_OpenMenu("BN_FRIEND", { name = "|Kq78|k", bnetIDAccount = 78 })
    W.menuItem(menu, "Whisper"):Pick()
    local c = UI.Active()
    T.ok(c, "conversation open")
    T.eq(c.kind, "w", "a character conversation, like Blizzard's own Whisper")
    T.eq(c.key, "kaela dawnmere")
    T.eq(next(ns.DB.bn), nil, "no Battle.net conversation")
    T.eq(W.focus, ns.Compose.box)
    T.no(box(G):IsShown())
end)

T.it("a whisper target that is the Battle.net account stays a Battle.net conversation", function()
    local G, W, ns, UI = load(function(G, W)
        bnFriend(G, W)
        W.bnFriends[1].titleTarget = "|Kq77|k" -- /w with the account token is a Battle.net whisper
    end)
    local menu = G.UnitPopup_OpenMenu("BN_FRIEND", { name = "|Kq77|k", bnetIDAccount = 77 })
    W.menuItem(menu, "Whisper"):Pick()
    local c = UI.Active()
    T.ok(c, "conversation open")
    T.eq(c.kind, "bn")
    T.eq(c.key, "bn:sunny#1234")
end)

T.it("an empty whisper target is no target", function()
    local G, W, ns, UI = load(function(G, W)
        bnFriend(G, W)
        W.bnFriends[1].titleTarget = ""
    end)
    local menu = G.UnitPopup_OpenMenu("BN_FRIEND", { name = "|Kq77|k", bnetIDAccount = 77 })
    W.menuItem(menu, "Whisper"):Pick()
    local c = UI.Active()
    T.ok(c, "conversation open")
    T.eq(c.kind, "bn")
end)

T.it("a Battle.net player known only by location still opens Sotto", function()
    local G, W, ns, UI = load(bnFriend)
    local menu = G.UnitPopup_OpenMenu("FRIEND", { name = "|Kq77|k", bnGUID = true })
    W.menuItem(menu, "Whisper"):Pick()
    local c = UI.Active()
    T.ok(c, "conversation open")
    T.eq(c.kind, "bn")
    T.eq(c.bnID, 77)
end)

T.it("Whisper opens Sotto in combat too: the player asked for it", function()
    local G, W, ns, UI = load()
    W.combat = true
    local menu = G.UnitPopup_OpenMenu("FRIEND", { name = "Tarin Ashgrove" })
    W.menuItem(menu, "Whisper"):Pick()
    T.ok(UI.IsShown())
    T.eq(UI.Active().key, "tarin ashgrove")
end)

T.it("Whisper closes the name field of +", function()
    local G, W, ns, UI = load()
    UI.NewConversation()
    T.ok(UI.prompt:IsShown())
    local menu = G.UnitPopup_OpenMenu("GUILD", { name = "Tarin Ashgrove" })
    W.menuItem(menu, "Whisper"):Pick()
    T.no(UI.prompt:IsShown(), "name field closed")
    T.eq(W.focus, ns.Compose.box)
end)

T.it("a closed conversation comes back", function()
    local G, W, ns, UI = load()
    local c = ns.Store.Ensure("w", "Tarin Ashgrove")
    ns.Store.Close(c)
    local menu = G.UnitPopup_OpenMenu("FRIEND", { name = "Tarin Ashgrove" })
    W.menuItem(menu, "Whisper"):Pick()
    T.eq(UI.Active(), c)
    T.ok(c.open, "back in the rail")
end)

-- When Sotto cannot carry the conversation, Whisper stays Blizzard's.
local function staysWithBlizzard(G, W, ns, UI, name)
    local menu = G.UnitPopup_OpenMenu("FRIEND", { name = name or "Tarin Ashgrove" })
    W.menuItem(menu, "Whisper"):Pick()
    T.eq(#W.menuWhispers, 1, "Blizzard's whisper ran")
    T.no(UI.IsShown(), "Sotto stays closed")
end

T.it("with \"Use Sotto to whisper\" off, Whisper stays Blizzard's", function()
    local G, W, ns, UI = load()
    ns.Set("intercept", false)
    staysWithBlizzard(G, W, ns, UI)
    T.ok(box(G):IsShown(), "Blizzard's chat box")
    T.eq(box(G):GetAttribute("tellTarget"), "Tarin Ashgrove")
end)

T.it("inside an instance Whisper stays Blizzard's", function()
    local G, W, ns, UI = load()
    W.instance = true
    staysWithBlizzard(G, W, ns, UI)
end)

T.it("in chat lockdown Whisper stays Blizzard's", function()
    local G, W, ns, UI = load()
    W.lockdown = true
    staysWithBlizzard(G, W, ns, UI)
end)

T.it("a name the client keeps secret stays Blizzard's", function()
    local G, W, ns, UI = load()
    staysWithBlizzard(G, W, ns, UI, T.secret("Tarin Ashgrove"))
end)

T.it("without Blizzard's menu list Sotto still knows the player menus", function()
    local G, W, ns, UI = load(function(G, W) G.UnitPopupMenus = nil end)
    T.eq(W.overrides["R"], "SOTTO_REPLY", "the reply keys are still bound")
    local menu = G.UnitPopup_OpenMenu("FRIEND", { name = "Tarin Ashgrove" })
    W.menuItem(menu, "Whisper"):Pick()
    T.ok(UI.IsShown(), "Sotto opens")
end)

local function chatLine(G, W)
    W.guids["Player-2-0001"] = { classLoc = "Warrior", classFile = "WARRIOR", raceLoc = "Orc", raceFile = "Orc",
        name = "Tarin Ashgrove" }
    W.chatLines[555] = { text = "lfg?", sender = "Tarin-Ashgrove", guid = "Player-2-0001" }
end

T.it("Whisper on a name in chat knows the class from that chat line", function()
    local G, W, ns, UI = load(chatLine)
    local menu = G.UnitPopup_OpenMenu("FRIEND", { name = "Tarin-Ashgrove", lineID = 555 })
    W.menuItem(menu, "Whisper"):Pick()
    T.eq(UI.Active().class, "WARRIOR", "class icon and colour from the start")
end)

T.it("a chat line from someone else lends no class", function()
    local G, W, ns, UI = load(chatLine)
    W.chatLines[556] = { text = "To Kaela Dawnmere: hi", sender = "Ayla-Brightwind", guid = "Player-2-0001" }
    local menu = G.UnitPopup_OpenMenu("FRIEND", { name = "Kaela-Dawnmere", lineID = 556 })
    W.menuItem(menu, "Whisper"):Pick()
    T.eq(UI.Active().key, "kaela dawnmere")
    T.eq(UI.Active().class, nil, "not the sender's class")
end)

T.it("in the gamepad interface Whisper in a player menu is the game's own", function()
    local G, W, ns, UI = load(function(G, W) W.interfaceStyle = 1 end)
    local menu = G.UnitPopup_OpenMenu("FRIEND", { name = "Tarin-Ashgrove", chatFrame = G.ChatFrame1 })
    W.menuItem(menu, "Whisper"):Pick()
    T.no(UI.IsShown(), "Sotto stays closed")
    T.eq(#W.menuWhispers, 1, "Blizzard's whisper ran: its chat box, made for the controller")
end)
