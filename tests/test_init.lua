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

-------------------------------------------------------------------------------
--  WoW Forever's gamepad interface
-------------------------------------------------------------------------------
-- Every GAMEPAD_CHANGED, in order, as "true" or "false".
local function gamepadNews(ns)
    local seen = {}
    ns.Listen("GAMEPAD_CHANGED", function(on) seen[#seen + 1] = tostring(on) end)
    return seen
end

T.it("Gamepad says whether WoW Forever's gamepad interface is on", function()
    local G, W, ns = T.load({ gamepad = true })
    T.eq(ns.Gamepad(), true)
    G, W, ns = T.load()
    T.eq(ns.Gamepad(), false, "the mouse interface")
end)

T.it("GAMEPAD_CHANGED comes a frame after the interface style changes, once per change", function()
    local G, W, ns = T.load()
    local seen = gamepadNews(ns)
    W.switchStyle("Gamepad")
    T.eq(#seen, 0, "not during the game's event: the style reads right only afterwards")
    W.advance(0)
    T.eq(table.concat(seen, ","), "true")
    W.switchStyle("Mkb")
    W.switchStyle("Gamepad")
    W.advance(0)
    T.eq(table.concat(seen, ","), "true", "a burst that ends where it began says nothing")
    W.switchStyle("Mkb")
    W.advance(0)
    T.eq(table.concat(seen, ","), "true,false")
    W.advance(1)
    T.eq(#seen, 2, "and nothing more")
end)

T.it("a style the client lacks, keeps secret or fails to give counts as the mouse interface", function()
    local errors = {}
    local G, W, ns = T.load({ gamepad = true, setup = function(G)
        G.geterrorhandler = function() return function(err) errors[#errors + 1] = err end end
    end })
    G.C_InputInterfaceStyle = nil
    T.eq(ns.Gamepad(), false, "no API (Retail, Classic)")
    G.C_InputInterfaceStyle = { GetCurrentStyle = "not a function" }
    T.eq(ns.Gamepad(), false)
    G.C_InputInterfaceStyle = { GetCurrentStyle = function() return T.secret(1) end }
    T.eq(ns.Gamepad(), false, "a secret style is never compared")
    G.C_InputInterfaceStyle = { GetCurrentStyle = function() error("style broke") end }
    T.eq(ns.Gamepad(), false, "a call that raises")
    G.C_InputInterfaceStyle = { GetCurrentStyle = function() return 1 end }
    G.Enum.InputDeviceInterfaceType = nil
    T.eq(ns.Gamepad(), false, "no enum to compare with")
    G.Enum.InputDeviceInterfaceType = { Mkb = 0, Gamepad = 1 }
    T.eq(ns.Gamepad(), true, "everything there again")
    T.eq(#errors, 0, "nothing was reported")
end)

T.it("a client without the style's event still reads the style", function()
    local G, W, ns = T.load({ gamepad = true, setup = function(G, W)
        W.unknownEvents.INPUT_DEVICE_INTERFACE_TRANSITION = true
    end })
    T.eq(ns.Gamepad(), true)
end)
