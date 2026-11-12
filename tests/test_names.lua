local T = T

local function load()
    local G, W, ns = T.load()
    return G, W, ns, ns.Names
end

T.it("same key for case and own-realm variants", function()
    local G, W, ns, N = load()
    local k = N.Key("Ayla Brightwind")
    T.eq(N.Key("ayla brightwind"), k)
    T.eq(N.Key("Ayla Brightwind-Forever Realm One"), k, "own realm, display form")
    T.eq(N.Key("Ayla Brightwind-ForeverRealmOne"), k, "own realm, normalized form")
end)

T.it("another realm keeps its own key", function()
    local G, W, ns, N = load()
    T.ok(N.Key("Bob-Other") ~= N.Key("Bob"), "different people")
    T.eq(N.Key("bob-other"), N.Key("Bob-Other"))
end)

T.it("Short is the first word without the realm", function()
    local G, W, ns, N = load()
    T.eq(N.Short("Ayla Brightwind"), "Ayla")
    T.eq(N.Short("Bob-Other"), "Bob")
    T.eq(N.Short("Tarin Ashgrove-Somewhere Else"), "Tarin")
end)

T.it("Display drops only the own realm", function()
    local G, W, ns, N = load()
    T.eq(N.Display("Ayla Brightwind-ForeverRealmOne"), "Ayla Brightwind")
    T.eq(N.Display("Bob-Other"), "Bob-Other")
    T.eq(N.Display("Tarin Ashgrove"), "Tarin Ashgrove")
end)

T.it("bad input does not raise", function()
    local G, W, ns, N = load()
    T.eq(N.Key(nil), nil)
    T.eq(N.Key(""), nil)
    T.eq(N.Key(T.secret("x")), nil)
    T.eq(N.Short(nil), "")
end)
