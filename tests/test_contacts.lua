local T = T

local function load(setup)
    local G, W, ns = T.load({ setup = setup })
    return G, W, ns, ns.Contacts, ns.Store
end

local function orcWarrior(G, W)
    W.guids["Player-2-0001"] = { classLoc = "Warrior", classFile = "WARRIOR", raceLoc = "Orc", raceFile = "Orc",
        name = "Tarin Ashgrove" }
end

T.it("GUID gives class and race", function()
    local G, W, ns, C, S = load(orcWarrior)
    local c = S.Ensure("w", "Tarin Ashgrove")
    C.Learn(c, "Player-2-0001")
    T.eq(c.class, "WARRIOR")
    T.eq(c.race, "Orc")
    T.eq(c.guid, "Player-2-0001")
end)

T.it("friends list gives level, zone and online state", function()
    local G, W, ns, C, S = load(function(G, W)
        W.friends = { { name = "Tarin Ashgrove", level = 34, className = "Warrior", area = "Desolace", connected = true } }
    end)
    local c = S.Ensure("w", "Tarin Ashgrove")
    C.Refresh(c)
    T.eq(c.level, 34)
    T.eq(c.zone, "Desolace")
    T.eq(c.online, true)
    T.eq(c.class, "WARRIOR")
end)

T.it("Meta order is level, race and class, zone", function()
    local G, W, ns, C, S = load(function(G, W)
        orcWarrior(G, W)
        W.friends = { { name = "Tarin Ashgrove", level = 34, className = "Warrior", area = "Desolace", connected = true } }
    end)
    local c = S.Ensure("w", "Tarin Ashgrove")
    C.Learn(c, "Player-2-0001")
    C.Refresh(c)
    local m = C.Meta(c)
    T.eq(#m, 3)
    T.eq(m[1], "34")
    T.eq(m[2], "Orc Warrior")
    T.eq(m[3], "Desolace")
end)

T.it("offline contact meta says offline", function()
    local G, W, ns, C, S = load(function(G, W)
        W.friends = { { name = "Tarin Ashgrove", level = 34, className = "Warrior", connected = false } }
    end)
    local c = S.Ensure("w", "Tarin Ashgrove")
    C.Refresh(c)
    local m = C.Meta(c)
    T.eq(m[#m], "offline")
    T.eq(c.online, false)
end)

T.it("guild roster fills in a guild mate", function()
    local G, W, ns, C, S = load(function(G, W)
        W.guild = { { name = "Tarin Ashgrove-ForeverRealmOne", level = 35, class = "Warrior", classFile = "WARRIOR",
            zone = "Orgrimmar", online = true } }
    end)
    local c = S.Ensure("w", "Tarin Ashgrove")
    C.Refresh(c)
    T.eq(c.level, 35)
    T.eq(c.zone, "Orgrimmar")
end)

T.it("targeting a contact updates level and class", function()
    local G, W, ns, C, S = load()
    local c = S.Ensure("w", "Tarin Ashgrove")
    W.units = { target = { name = "Tarin Ashgrove", level = 36, class = "Warrior", classFile = "WARRIOR", race = "Orc",
        guid = "Player-2-0001" } }
    W.fire("PLAYER_TARGET_CHANGED")
    T.eq(c.level, 36)
    T.eq(c.class, "WARRIOR")
    T.eq(c.race, "Orc")
end)

T.it("secret values are ignored", function()
    local G, W, ns, C, S = load(function(G, W)
        W.friends = { { name = "Tarin Ashgrove", level = T.secret(34), area = T.secret("x"), connected = true } }
    end)
    local c = S.Ensure("w", "Tarin Ashgrove")
    C.Learn(c, T.secret("Player-2-0001"))
    C.Refresh(c)
    T.eq(c.level, nil)
    T.eq(c.zone, nil)
    T.eq(c.guid, nil)
end)

T.it("Battle.net friend in game shows character and zone", function()
    local G, W, ns, C, S = load(function(G, W)
        W.bnFriends = { { bnetAccountID = 5, accountName = "|Kq5|k", battleTag = "Alex#1234",
            gameAccountInfo = { isOnline = true, clientProgram = "WoW", characterName = "Brann",
                className = "Hunter", raceName = "Troll", characterLevel = 35, areaName = "Orgrimmar" } } }
    end)
    local c = S.Ensure("bn", "|Kq5|k", { tag = "Alex#1234", bnID = 5 })
    C.Refresh(c)
    local m = C.Meta(c)
    T.eq(m[1], "Battle.net")
    T.eq(m[2], "Brann")
    T.eq(m[3], "Orgrimmar")
    T.eq(c.online, true)
end)

T.it("Initials come from the BattleTag or the two words of a name", function()
    local G, W, ns, C, S = load()
    T.eq(C.Initials(S.Ensure("bn", "|Kq5|k", { tag = "Alex#1234", bnID = 5 })), "AL")
    T.eq(C.Initials(S.Ensure("w", "Kaja Stormhoof")), "KS")
    T.eq(C.Initials(S.Ensure("w", "Bob")), "BO")
end)

T.it("Color is the class colour, Battle.net blue, or text", function()
    local G, W, ns, C, S = load(orcWarrior)
    local c = S.Ensure("w", "Tarin Ashgrove")
    C.Learn(c, "Player-2-0001")
    local r, g, b = C.Color(c)
    T.near(r, 0.78)
    local bn = S.Ensure("bn", "|Kq5|k", { tag = "Alex#1234", bnID = 5 })
    r, g, b = C.Color(bn)
    T.near(b, 1)
end)

T.it("Icon uses the class icon when the class is known", function()
    local G, W, ns, C, S = load(orcWarrior)
    local c = S.Ensure("w", "Tarin Ashgrove")
    T.eq(C.Icon(c), nil)
    C.Learn(c, "Player-2-0001")
    local icon = C.Icon(c)
    T.ok(icon and (icon.atlas or icon.texture), "icon")
end)
