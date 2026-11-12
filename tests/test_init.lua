local T = T

T.it("an unpackaged copy reports its version as dev", function()
    local G, W, ns = T.load()
    T.eq(ns.version, "dev")
end)

T.it("IsSecret spots a secret among plain values", function()
    local G, W, ns = T.load()
    T.ok(ns.IsSecret("a", T.secret("x"), 1), "secret found")
    T.no(ns.IsSecret("a", 1, nil, false), "plain values")
end)

T.it("On runs handlers for game events and Off removes them", function()
    local G, W, ns = T.load()
    local got = {}
    local function h(event, a) got[#got + 1] = event .. ":" .. tostring(a) end
    ns.On("SOME_EVENT", h)
    W.fire("SOME_EVENT", 1)
    ns.Off("SOME_EVENT", h)
    W.fire("SOME_EVENT", 2)
    T.eq(#got, 1, "one call")
    T.eq(got[1], "SOME_EVENT:1")
end)

T.it("a failing handler does not stop the next one", function()
    local G, W, ns = T.load()
    local ran = false
    ns.On("OTHER_EVENT", function() error("boom") end)
    ns.On("OTHER_EVENT", function() ran = true end)
    pcall(W.fire, "OTHER_EVENT")
    T.ok(ran, "second handler ran")
end)

T.it("Listen and Fire pass arguments", function()
    local G, W, ns = T.load()
    local seen
    ns.Listen("THING", function(a, b) seen = a .. b end)
    ns.Fire("THING", "x", "y")
    T.eq(seen, "xy")
end)

T.it("InLockdown reads the chat messaging lockdown", function()
    local G, W, ns = T.load()
    T.no(ns.InLockdown())
    W.lockdown = true
    T.ok(ns.InLockdown())
end)

T.it("After runs a callback after the delay", function()
    local G, W, ns = T.load()
    local ran = false
    ns.After(1, function() ran = true end)
    W.advance(0.5)
    T.no(ran, "not yet")
    W.advance(0.6)
    T.ok(ran, "ran")
end)
