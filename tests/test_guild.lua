local T = T

-- "Invite to guild" in a conversation's "…" menu, as WIM's shortcut bar has it:
-- there while the player may invite to their guild (CanGuildInvite) and the
-- contact is a character not yet in it. A Battle.net friend counts only as a
-- character this game can reach (Blizzard's friends list: the same version of
-- the game, realm info, on Classic the same realm), named with their realm when
-- it is another one (WoW Forever's names are unique without it). The header's
-- group invite follows the same rule.

local function whisper(W, text, sender, o)
    W.chat("CHAT_MSG_WHISPER", W.whisperArgs(text, sender, o))
end

-- A row of the open menu of Sotto's, by its text.
local function entry(ns, text)
    local menu = ns.W.CurrentMenu()
    if not menu or not menu:IsShown() then return nil end
    for _, row in ipairs(menu.rows) do
        if row:IsShown() and row.label:GetText() == text then return row end
    end
end

local function more(ns) ns.UI.MoreMenu(ns.UI.header.more) end

-- A Battle.net friend playing Robin Vale (o: project, realmID, realm) whispers.
local function robin(G, W, ns, o)
    o = o or {}
    W.bnFriends = { { bnetAccountID = 5, accountName = "|Kq5|k", battleTag = "Alex#1234",
        gameAccountInfo = { isOnline = true, clientProgram = "WoW", characterName = "Robin Vale",
            wowProjectID = o.project or G.WOW_PROJECT_ID, realmID = o.realmID or 1,
            realmName = o.realm or "Forever Realm One" } } }
    W.chat("CHAT_MSG_BN_WHISPER", W.whisperArgs("hey", "|Kq5|k", { bnID = 5 }))
    return ns.Store.Get("bn:alex#1234")
end

T.it("the … menu invites the character to the guild", function()
    local G, W, ns = T.load()
    W.canGuildInvite = true
    whisper(W, "lf guild?", "Tarin Ashgrove")
    more(ns)
    local row = entry(ns, "Invite to guild")
    T.ok(row, "there")
    row:Click()
    T.eq(W.guildInvited, "Tarin Ashgrove")
end)

T.it("without the right to invite there is no entry", function()
    local G, W, ns = T.load()
    whisper(W, "lf guild?", "Tarin Ashgrove")
    more(ns)
    T.no(entry(ns, "Invite to guild"))
    T.ok(entry(ns, "Copy name"), "the rest of the menu is there")
end)

T.it("a member of the guild gets no entry", function()
    local G, W, ns = T.load()
    W.canGuildInvite = true
    W.guild = { { name = "Tarin Ashgrove", level = 60, class = "Mage", classFile = "MAGE", online = true } }
    whisper(W, "hi", "Tarin Ashgrove")
    more(ns)
    T.no(entry(ns, "Invite to guild"))
end)

T.it("a Battle.net friend on this realm is invited as the character they play", function()
    local G, W, ns = T.load()
    W.canGuildInvite = true
    local c = robin(G, W, ns)
    T.eq(c.char, "Robin Vale", "playing that character")
    more(ns)
    entry(ns, "Invite to guild"):Click()
    T.eq(W.guildInvited, "Robin Vale")
    ns.UI.header.invite:Click()
    T.eq(W.invited, "Robin Vale", "the group invite too")
end)

T.it("a Battle.net friend who leaves the game is no longer invited", function()
    local G, W, ns = T.load()
    W.canGuildInvite = true
    local c = robin(G, W, ns)
    W.bnFriends[1].gameAccountInfo = { isOnline = true, clientProgram = "App" }
    ns.Contacts.Refresh(c)
    more(ns)
    T.no(entry(ns, "Invite to guild"))
    T.no(ns.UI.header.invite:IsEnabled())
end)

T.it("a Battle.net friend in another version of the game is out of reach", function()
    local G, W, ns = T.load()
    W.canGuildInvite = true
    robin(G, W, ns, { project = G.WOW_PROJECT_CLASSIC })
    more(ns)
    T.no(entry(ns, "Invite to guild"), "a same-named stranger here would get it")
    T.no(ns.UI.header.invite:IsEnabled(), "no group invite either")
end)

T.it("a Battle.net friend without realm info is out of reach", function()
    local G, W, ns = T.load()
    W.canGuildInvite = true
    robin(G, W, ns, { realmID = 0 })
    more(ns)
    T.no(entry(ns, "Invite to guild"))
    T.no(ns.UI.header.invite:IsEnabled())
end)

T.it("on Retail a Battle.net friend on another realm is invited with the realm", function()
    local G, W, ns = T.load()
    W.run = false
    W.canGuildInvite = true
    robin(G, W, ns, { realmID = 7, realm = "Argent Dawn" })
    more(ns)
    entry(ns, "Invite to guild"):Click()
    T.eq(W.guildInvited, "Robin Vale-ArgentDawn")
    ns.UI.header.invite:Click()
    T.eq(W.invited, "Robin Vale-ArgentDawn")
end)

T.it("on Retail a Battle.net friend on this realm is invited by name alone", function()
    local G, W, ns = T.load()
    W.run = false
    W.canGuildInvite = true
    robin(G, W, ns, { realmID = 1, realm = "Forever Realm One" })
    more(ns)
    entry(ns, "Invite to guild"):Click()
    T.eq(W.guildInvited, "Robin Vale")
end)

T.it("on WoW Forever a friend on another realm needs no realm: names are unique", function()
    local G, W, ns = T.load()
    W.canGuildInvite = true
    robin(G, W, ns, { realmID = 7, realm = "Forever Realm Two" })
    more(ns)
    entry(ns, "Invite to guild"):Click()
    T.eq(W.guildInvited, "Robin Vale")
end)

T.it("on Classic a Battle.net friend on another realm is out of reach", function()
    local G, W, ns = T.load()
    W.run = false
    G.WOW_PROJECT_ID = G.WOW_PROJECT_CLASSIC
    W.canGuildInvite = true
    robin(G, W, ns, { project = G.WOW_PROJECT_CLASSIC, realmID = 7, realm = "Pagle" })
    more(ns)
    T.no(entry(ns, "Invite to guild"))
    T.no(ns.UI.header.invite:IsEnabled())
end)

T.it("separate windows have it too", function()
    local G, W, ns = T.load()
    ns.Set("separate", true)
    W.canGuildInvite = true
    whisper(W, "hi", "Tarin Ashgrove")
    local w = ns.Windows.For(ns.Store.Get("tarin ashgrove"))
    w.pane:MoreMenu(w.pane.head.more)
    entry(ns, "Invite to guild"):Click()
    T.eq(W.guildInvited, "Tarin Ashgrove")
end)
