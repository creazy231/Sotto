local T = T

local function load(setup)
    local G, W, ns = T.load({ setup = setup })
    return G, W, ns, ns.Engine, ns.Store
end

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

T.it("whisper creates a conversation and an incoming message", function()
    local G, W, ns, E, S = load()
    ns.Set("openOn", "never") -- an opened window would mark it read
    whisper(W, "hey", "Tarin Ashgrove", { guid = "Player-2-0001" })
    local c = S.Get("tarin ashgrove")
    T.ok(c, "conversation")
    T.eq(#c.msgs, 1)
    T.eq(c.msgs[1].d, "i")
    T.eq(c.msgs[1].m, "hey")
    T.eq(c.unread, 1)
    T.eq(c.online, true)
end)

T.it("inform adds an outgoing message and clears unread", function()
    local G, W, ns, E, S = load()
    whisper(W, "hey", "Tarin Ashgrove")
    W.chat("CHAT_MSG_WHISPER_INFORM", W.whisperArgs("hi", "Tarin Ashgrove"))
    local c = S.Get("tarin ashgrove")
    T.eq(#c.msgs, 2)
    T.eq(c.msgs[2].d, "o")
    T.eq(c.unread, 0)
end)

T.it("whisper from 'ayla brightwind' joins 'Ayla Brightwind'", function()
    local G, W, ns, E, S = load()
    whisper(W, "a", "Ayla Brightwind")
    whisper(W, "b", "ayla brightwind")
    T.eq(#S.Get("ayla brightwind").msgs, 2)
    T.eq(#S.List(), 1)
end)

T.it("the sender's spelling becomes the conversation name", function()
    local G, W, ns, E, S = load()
    S.Ensure("w", "ayla brightwind")
    whisper(W, "hi", "Ayla Brightwind")
    T.eq(S.Get("ayla brightwind").name, "Ayla Brightwind")
end)

T.it("an outgoing whisper stays in chat while Sotto cannot show it", function()
    local G, W, ns, E, S = load()
    W.combat = true
    W.chat("CHAT_MSG_WHISPER_INFORM", W.whisperArgs("on my way", "Tarin Ashgrove"))
    T.ok(shownInChat(W, "on my way"), "visible in chat")
    T.no(ns.UI.IsShown())
    T.eq(#S.Get("tarin ashgrove").msgs, 1, "and recorded in Sotto")
end)

T.it("an outgoing whisper out of combat opens its conversation in Sotto", function()
    local G, W, ns, E, S = load()
    W.chat("CHAT_MSG_WHISPER_INFORM", W.whisperArgs("on my way", "Tarin Ashgrove"))
    T.no(shownInChat(W, "on my way"), "moved to Sotto")
    T.ok(ns.UI.IsShown(), "window open")
    T.eq(ns.UI.Active(), S.Get("tarin ashgrove"))
    T.no(W.focus, "no focus taken")
end)

T.it("AFK replies stay in chat while Sotto is hidden", function()
    local G, W, ns, E, S = load()
    W.combat = true
    W.chat("CHAT_MSG_WHISPER_INFORM", W.whisperArgs("you there?", "Tarin Ashgrove"))
    W.chat("CHAT_MSG_AFK", W.whisperArgs("brb food", "Tarin Ashgrove"))
    T.ok(shownInChat(W, "brb food"))
end)

T.it("nothing is hidden from chat until Sotto's window exists", function()
    local files = {}
    for _, f in ipairs(T.tocFiles()) do if f:find("^Core/") then files[#files + 1] = f end end
    local G, W, ns = T.load({ only = files })
    W.chat("CHAT_MSG_WHISPER", W.whisperArgs("still here", "Tarin Ashgrove"))
    T.ok(shownInChat(W, "still here"))
end)

T.it("filter hides handled whispers only when hideInChat is on", function()
    local G, W, ns, E, S = load()
    whisper(W, "hidden", "Tarin Ashgrove")
    T.no(shownInChat(W, "hidden"), "hidden from chat")
    ns.Set("hideInChat", false)
    whisper(W, "visible", "Tarin Ashgrove")
    T.ok(shownInChat(W, "visible"), "shown in chat")
    T.eq(#S.Get("tarin ashgrove").msgs, 2, "both in Sotto")
end)

T.it("GM whispers and letterbox lines are left to Blizzard", function()
    local G, W, ns, E, S = load()
    whisper(W, "gm", "Gamemaster", { flags = "GM" })
    T.eq(S.Get("gamemaster"), nil)
    whisper(W, "box", "Narrator", { letterbox = true })
    T.eq(S.Get("narrator"), nil)
    T.ok(shownInChat(W, "box"), "letterbox stays in chat")
end)

T.it("secret whisper in lockdown is queued and not filtered", function()
    local G, W, ns, E, S = load()
    W.lockdown = true
    local secretText = T.secret("hey")
    W.chat("CHAT_MSG_WHISPER", W.whisperArgs(secretText, T.secret("Tarin Ashgrove"), { lineID = 555 }))
    T.eq(S.Get("tarin ashgrove"), nil, "nothing shown in Sotto")
    T.eq(E.QueueSize(), 1)
    local inChat = false
    for _, e in ipairs(W.chatLog) do if type(e) == "table" and e.text == secretText then inChat = true end end
    T.ok(inChat, "stays in the chat window")
end)

T.it("queued whisper is recovered once after the lockdown with its original time", function()
    local G, W, ns, E, S = load()
    W.lockdown = true
    local t0 = G.time()
    W.chat("CHAT_MSG_WHISPER", W.whisperArgs(T.secret("hey"), T.secret("Tarin Ashgrove"), { lineID = 555 }))
    W.chatLines[555] = { text = "hey", sender = "Tarin Ashgrove", guid = "Player-2-0001" }
    W.advance(60)
    W.lockdown = false
    W.fire("ADDON_RESTRICTION_STATE_CHANGED", 5, 0)
    W.advance(1)
    local c = S.Get("tarin ashgrove")
    T.ok(c, "recovered")
    T.eq(#c.msgs, 1)
    T.eq(c.msgs[1].t, t0)
    T.eq(E.QueueSize(), 0)
    W.fire("ENCOUNTER_END")
    W.advance(1)
    T.eq(#c.msgs, 1, "not twice")
end)

T.it("a Battle.net whisper in lockdown is recovered into its Battle.net conversation", function()
    local G, W, ns, E, S = load(alex)
    W.lockdown = true
    -- In lockdown the account id is secret too; the chat line keeps text and sender.
    W.chat("CHAT_MSG_BN_WHISPER", W.whisperArgs(T.secret("pull in 5?"), T.secret("|Kq5|k"),
        { lineID = 901, bnID = T.secret(5) }))
    W.chatLines[901] = { text = "pull in 5?", sender = "|Kq5|k", guid = "" }
    T.eq(S.Get("bn:alex#1234"), nil, "nothing readable yet")
    W.lockdown = false
    W.fire("ADDON_RESTRICTION_STATE_CHANGED", 5, 0)
    W.advance(1)
    local c = S.Get("bn:alex#1234")
    T.ok(c, "recovered into the Battle.net conversation")
    T.eq(c.msgs[#c.msgs].m, "pull in 5?")
    T.eq(c.msgs[#c.msgs].d, "i")
end)

T.it("a Battle.net whisper from a friend who logged off during the fight is recovered too", function()
    local G, W, ns, E, S = load(alex)
    W.lockdown = true
    W.chat("CHAT_MSG_BN_WHISPER", W.whisperArgs(T.secret("gtg, bye"), T.secret("|Kq5|k"),
        { lineID = 902, bnID = T.secret(5) }))
    W.chatLines[902] = { text = "gtg, bye", sender = "|Kq5|k", guid = "" }
    W.bnFriends[1].gameAccountInfo = { isOnline = false, clientProgram = "" }
    W.lockdown = false
    W.fire("ADDON_RESTRICTION_STATE_CHANGED", 5, 0)
    W.advance(1)
    local c = S.Get("bn:alex#1234")
    T.ok(c, "found through the friend list")
    T.eq(c.msgs[#c.msgs].m, "gtg, bye")
end)

T.it("unrecoverable lines are dropped quietly", function()
    local G, W, ns, E, S = load()
    W.lockdown = true
    W.chat("CHAT_MSG_WHISPER", W.whisperArgs(T.secret("x"), T.secret("Y"), { lineID = 777 }))
    W.lockdown = false
    W.fire("ADDON_RESTRICTION_STATE_CHANGED", 5, 0)
    W.advance(1)
    T.eq(E.QueueSize(), 0)
    T.eq(#S.List(), 0)
end)

T.it("secret whisper outside lockdown is ignored", function()
    local G, W, ns, E, S = load()
    W.chat("CHAT_MSG_WHISPER", W.whisperArgs(T.secret("hey"), T.secret("Tarin Ashgrove")))
    T.eq(E.QueueSize(), 0)
    T.eq(#S.List(), 0)
end)

T.it("in combat with openOn=nocombat no window is wanted", function()
    local G, W, ns, E, S = load()
    local want = {}
    ns.Listen("INCOMING", function(conv, msg, wantOpen) want[#want + 1] = wantOpen end)
    whisper(W, "a", "Tarin Ashgrove")
    W.combat = true
    whisper(W, "b", "Tarin Ashgrove")
    ns.Set("openOn", "always")
    whisper(W, "c", "Tarin Ashgrove")
    ns.Set("openOn", "never")
    W.combat = false
    whisper(W, "d", "Tarin Ashgrove")
    T.eq(want[1], true)
    T.eq(want[2], false)
    T.eq(want[3], true)
    T.eq(want[4], false)
end)

T.it("Send splits long text and is refused in lockdown", function()
    local G, W, ns, E, S = load()
    local c = S.Ensure("w", "Tarin Ashgrove")
    local words = {}
    for i = 1, 120 do words[i] = "word" .. i end
    local text = table.concat(words, " ")
    local expected = #ns.Format.Split(text, 255)
    T.eq(expected, 4, "851 bytes make four messages")
    T.ok(E.Send(c, text), "sent")
    T.eq(#W.sent, 2, "two right away")
    W.advance(1)
    T.eq(#W.sent, expected, "the rest paced")
    for _, s in ipairs(W.sent) do
        T.ok(#s.msg <= 255, "limit")
        T.eq(s.chatType, "WHISPER")
        T.eq(s.target, "Tarin Ashgrove")
    end
    W.lockdown = true
    T.no(E.Send(c, "blocked"), "refused")
    T.eq(#W.sent, expected)
end)

T.it("Send ignores blank text", function()
    local G, W, ns, E, S = load()
    local c = S.Ensure("w", "Tarin Ashgrove")
    T.no(E.Send(c, "   "))
    T.eq(#W.sent, 0)
end)

T.it("Battle.net whisper creates a Battle.net conversation", function()
    local G, W, ns, E, S = load(alex)
    W.chat("CHAT_MSG_BN_WHISPER", W.whisperArgs("sup", "|Kq5|k", { bnID = 5 }))
    local c = S.Get("bn:alex#1234")
    T.ok(c, "conversation")
    T.eq(c.msgs[1].m, "sup")
    T.eq(c.bnID, 5)
end)

T.it("Battle.net whisper with a secret sender but readable text and id still arrives", function()
    local G, W, ns, E, S = load(alex)
    W.chat("CHAT_MSG_BN_WHISPER", W.whisperArgs("sup", T.secret("|Kq5|k"), { bnID = 5 }))
    T.ok(S.Get("bn:alex#1234"), "conversation")
end)

-- WoW Forever: a friend the game whispers by character (C_BattleNet.GetDefaultTitleWhisperTarget).
local function titleFriend(G, W)
    W.bnFriends = { { bnetAccountID = 8, accountName = "|Kq8|k", battleTag = "", titleTarget = "Kaela Dawnmere",
        gameAccountInfo = { isOnline = true, clientProgram = "WoW", characterName = "Kaela Dawnmere" } } }
end

T.it("a Battle.net whisper from a friend the game whispers by character joins that character's conversation", function()
    local G, W, ns, E, S = load(titleFriend)
    W.chat("CHAT_MSG_WHISPER", W.whisperArgs("hey", "Kaela Dawnmere"))
    W.chat("CHAT_MSG_BN_WHISPER", W.whisperArgs("still there?", "|Kq8|k", { bnID = 8 }))
    W.chat("CHAT_MSG_BN_WHISPER_INFORM", W.whisperArgs("yes!", "|Kq8|k", { bnID = 8 }))
    local c = S.Get("kaela dawnmere")
    T.ok(c, "the character's conversation")
    T.eq(#c.msgs, 3, "one conversation for the person")
    T.eq(c.msgs[3].d, "o")
    T.eq(next(ns.DB.bn), nil, "no Battle.net conversation")
end)

T.it("Battle.net send uses the account id", function()
    local G, W, ns, E, S = load(alex)
    local c = S.Ensure("bn", "|Kq5|k", { tag = "Alex#1234", bnID = 5 })
    T.ok(E.Send(c, "yo"))
    T.eq(W.bnSent[1].id, 5)
    T.eq(W.bnSent[1].text, "yo")
end)

T.it("AFK and DND replies become system lines", function()
    local G, W, ns, E, S = load()
    W.chat("CHAT_MSG_WHISPER_INFORM", W.whisperArgs("you there?", "Tarin Ashgrove"))
    W.chat("CHAT_MSG_AFK", W.whisperArgs("brb food", "Tarin Ashgrove"))
    local c = S.Get("tarin ashgrove")
    local m = c.msgs[#c.msgs]
    T.eq(m.d, "s")
    T.eq(m.s, "afk")
    T.ok(m.m:find("brb food", 1, true), m.m)
    T.no(shownInChat(W, "brb food"), "hidden from chat")
end)

T.it("player not found becomes a system line and marks offline", function()
    local G, W, ns, E, S = load()
    W.chat("CHAT_MSG_WHISPER_INFORM", W.whisperArgs("hi", "Tarin Ashgrove"))
    W.chat("CHAT_MSG_SYSTEM", "No player named 'Tarin Ashgrove' is currently playing.")
    local c = S.Get("tarin ashgrove")
    T.eq(c.msgs[#c.msgs].d, "s")
    T.eq(c.online, false)
end)

T.it("a Battle.net whisper to an offline friend says so in its conversation", function()
    local G, W, ns, E, S = load(alex)
    local c = S.Ensure("bn", "|Kq5|k", { tag = "Alex#1234", bnID = 5 })
    ns.UI.Open(c)
    W.chat("CHAT_MSG_BN_WHISPER_PLAYER_OFFLINE", W.whisperArgs("Alex is offline.", "|Kq5|k", { bnID = 5 }))
    local m = c.msgs[#c.msgs]
    T.ok(m, "a line in the conversation")
    T.eq(m.d, "s")
    T.eq(m.m, "Alex is offline.")
    T.eq(c.online, false)
    T.no(shownInChat(W, "Alex is offline."), "hidden from chat while Sotto shows it")
end)

T.it("an offline notice stays in chat while Sotto is hidden", function()
    local G, W, ns, E, S = load(alex)
    local c = S.Ensure("bn", "|Kq5|k", { tag = "Alex#1234", bnID = 5 })
    W.chat("CHAT_MSG_BN_WHISPER_PLAYER_OFFLINE", W.whisperArgs("Alex is offline.", "|Kq5|k", { bnID = 5 }))
    T.ok(shownInChat(W, "Alex is offline."))
    T.eq(c.msgs[#c.msgs].m, "Alex is offline.", "and in the conversation")
end)

T.it("a whisper another addon hides from chat stays out of Sotto", function()
    local G, W, ns, E, S = load()
    G.ChatFrameUtil.AddMessageEventFilter("CHAT_MSG_WHISPER", function(_, _, msg)
        return msg:find("^WTS gold") ~= nil -- a spam filter
    end)
    whisper(W, "WTS gold cheap", "Spam Bot")
    T.eq(S.Get("spam bot"), nil, "the spam filter's call")
    whisper(W, "hey", "Tarin Ashgrove")
    T.ok(S.Get("tarin ashgrove"), "everything else arrives")
end)

T.it("while WIM still runs, its filter does not empty Sotto", function()
    local G, W, ns, E, S = load(function(G, W) W.loadedAddons.WIM = true end)
    -- WIM hides every whisper it shows itself; Sotto offers to turn it off.
    G.ChatFrameUtil.AddMessageEventFilter("CHAT_MSG_WHISPER", function() return true end)
    whisper(W, "hey", "Tarin Ashgrove")
    T.ok(S.Get("tarin ashgrove"), "shown in Sotto too")
end)

T.it("a filter that keeps whispers out of the main chat tab does not empty Sotto", function()
    local G, W, ns, E, S = load()
    -- A chat addon that shows whispers in a tab of its own.
    G.ChatFrameUtil.AddMessageEventFilter("CHAT_MSG_WHISPER", function(frame) return frame == G.DEFAULT_CHAT_FRAME end)
    whisper(W, "hey", "Tarin Ashgrove")
    T.ok(S.Get("tarin ashgrove"))
end)

T.it("a system line another addon hides stays out of the conversation", function()
    local G, W, ns, E, S = load()
    W.chat("CHAT_MSG_WHISPER", W.whisperArgs("hey", "Tarin Ashgrove"))
    local c = S.Get("tarin ashgrove")
    -- An addon whose own hidden message could not be delivered hides the game's line.
    G.ChatFrameUtil.AddMessageEventFilter("CHAT_MSG_SYSTEM", function(_, _, msg)
        return msg:find("^No player named") ~= nil
    end)
    W.chat("CHAT_MSG_SYSTEM", "No player named 'Tarin Ashgrove' is currently playing.")
    T.eq(#c.msgs, 1, "no line")
    T.eq(c.online, true, "still online")
end)

T.it("reporting a player removes their whispers, as Blizzard's chat does", function()
    local G, W, ns, E, S = load()
    whisper(W, "WTB your account", "Odd Stranger", { guid = "Player-2-0099" })
    whisper(W, "hey", "Tarin Ashgrove", { guid = "Player-2-0001" })
    W.chat("CHAT_MSG_WHISPER_INFORM", W.whisperArgs("hi", "Tarin Ashgrove", { guid = "Player-2-0001" }))
    W.fire("PLAYER_REPORT_SUBMITTED", "Player-2-0099")
    local odd = S.Get("odd stranger")
    T.eq(#odd.msgs, 0, "their lines are gone")
    T.no(odd.open, "and the empty conversation leaves the rail")
    T.eq(#S.Get("tarin ashgrove").msgs, 2, "everyone else is untouched")
    W.fire("PLAYER_REPORT_SUBMITTED", "Player-2-0001")
    local tarin = S.Get("tarin ashgrove")
    T.eq(#tarin.msgs, 1, "your own line stays")
    T.eq(tarin.msgs[1].d, "o")
    T.ok(tarin.open)
end)

T.it("sound respects the setting and the 2 s cool-down", function()
    local G, W, ns, E, S = load()
    whisper(W, "a", "Tarin Ashgrove")
    T.eq(#W.sounds, 1)
    T.ok(W.sounds[1].file and W.sounds[1].file:find("chime"), "chime")
    whisper(W, "b", "Tarin Ashgrove")
    T.eq(#W.sounds, 1, "cool-down")
    W.advance(3)
    ns.Set("sound", "game")
    whisper(W, "c", "Tarin Ashgrove")
    T.eq(W.sounds[2].kit, 3081)
    W.advance(3)
    ns.Set("sound", "none")
    whisper(W, "d", "Tarin Ashgrove")
    T.eq(#W.sounds, 2)
end)

T.it("with hideInChat off the game plays its own sound and flash", function()
    local G, W, ns, E, S = load()
    ns.Set("hideInChat", false)
    whisper(W, "a", "Tarin Ashgrove")
    T.eq(#W.sounds, 1, "only Blizzard's")
    T.eq(W.sounds[1].kit, 3081)
    T.eq(W.flashes, 0)
end)

T.it("a hidden whisper flashes the client icon", function()
    local G, W, ns, E, S = load()
    whisper(W, "a", "Tarin Ashgrove")
    T.eq(W.flashes, 1)
end)

T.it("LastIncoming and LastOutgoing", function()
    local G, W, ns, E, S = load()
    whisper(W, "a", "Aaa")
    W.chat("CHAT_MSG_WHISPER_INFORM", W.whisperArgs("b", "Bbb"))
    T.eq(E.LastIncoming(), S.Get("aaa"))
    T.eq(E.LastOutgoing(), S.Get("bbb"))
end)

T.it("LastIncoming after a reload is the newest incoming message on record", function()
    local now = 1794499200
    local CHAR = "Player-1-00000001"
    local db = { chars = { [CHAR] = { convs = {
        aaa = { key = "aaa", kind = "w", name = "Aaa", unread = 0, open = true, last = now - 50,
            msgs = { { t = now - 100, d = "i", m = "x" }, { t = now - 50, d = "o", m = "y" } } },
        bbb = { key = "bbb", kind = "w", name = "Bbb", unread = 0, open = true, last = now - 80,
            msgs = { { t = now - 80, d = "i", m = "z" } } },
    } } } }
    local G, W, ns = T.load({ db = db })
    T.eq(ns.Engine.LastIncoming(), ns.Store.Get("bbb"))
    T.eq(ns.Engine.LastOutgoing(), ns.Store.Get("aaa"))
end)

T.it("lockdown changes fire LOCKDOWN_CHANGED", function()
    local G, W, ns, E, S = load()
    local got = {}
    ns.Listen("LOCKDOWN_CHANGED", function(v) got[#got + 1] = v end)
    W.lockdown = true
    W.fire("ENCOUNTER_START")
    W.lockdown = false
    W.fire("ENCOUNTER_END")
    T.eq(got[1], true)
    T.eq(got[2], false)
    T.no(E.Locked())
end)
