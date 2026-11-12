local T = T

T.it("defaults fill a fresh SottoDB", function()
    local G, W, ns = T.load()
    local s = G.SottoDB.settings
    T.eq(s.openOn, "nocombat")
    T.eq(s.sound, "chime")
    T.eq(s.hideInChat, true)
    T.eq(s.intercept, true)
    T.eq(s.accent, "class")
    T.eq(s.fontSize, 13)
    T.eq(s.fadeIdle, true)
    T.eq(s.keepDays, 30)
    T.eq(s.minimap, true)
    T.eq(ns.Get("fontSize"), 13)
end)

T.it("Set stores the value and fires SETTING_CHANGED", function()
    local G, W, ns = T.load()
    local got
    ns.Listen("SETTING_CHANGED", function(k, v) got = k .. "=" .. tostring(v) end)
    ns.Set("sound", "none")
    T.eq(G.SottoDB.settings.sound, "none")
    T.eq(got, "sound=none")
end)

T.it("an existing SottoDB keeps its values and unknown keys", function()
    local G, W, ns = T.load({ db = { settings = { sound = "game", future = 1 }, extra = true } })
    T.eq(ns.Get("sound"), "game")
    T.eq(G.SottoDB.settings.future, 1)
    T.eq(G.SottoDB.extra, true)
    T.eq(ns.Get("openOn"), "nocombat", "missing keys get defaults")
end)

T.it("CharKey is the character's GUID", function()
    local G, W, ns = T.load()
    T.eq(ns.CharKey(), "Player-1-00000001")
end)

T.it("window geometry has defaults", function()
    local G, W, ns = T.load()
    local w = G.SottoDB.window
    T.eq(w.w, 410)
    T.eq(w.h, 306)
end)
