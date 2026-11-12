local T = T

T.it("Shift lightens EllesmereUI's panel grey the way Polestar derives its panel", function()
    local G, W, ns = T.load()
    T.color(ns.Color.Shift({ 0.08, 0.08, 0.08, 0.92 }, 0.02), "191919")
    T.color(ns.Color.Shift({ 0.08, 0.08, 0.08 }, -0.03), "0e0e0e")
    T.color(ns.Color.Shift({ 0.08, 0.08, 0.08 }, 0.09, 1.6), "2a2a2a")
end)

T.it("Shift keeps alpha", function()
    local G, W, ns = T.load()
    T.eq(ns.Color.Shift({ 0.5, 0.5, 0.5, 0.25 }, 0.1)[4], 0.25)
end)

T.it("Contrast of white on black is 21", function()
    local G, W, ns = T.load()
    T.near(ns.Color.Contrast({ 1, 1, 1 }, { 0, 0, 0 }), 21, 0.01)
end)

T.it("Lift moves the shaman blue to 4.5:1 on the panel", function()
    local G, W, ns = T.load()
    local panel, text = { 0x19 / 255, 0x19 / 255, 0x19 / 255 }, { 0.974, 0.974, 0.974 }
    local r, g, b = ns.Color.Lift(panel, text, { 0, 0.44, 0.87 }, 4.5)
    T.ok(ns.Color.Contrast({ r, g, b }, panel) >= 4.5, "legible")
    T.color({ r, g, b }, "2585e2")
end)

T.it("Lift leaves a legible colour alone", function()
    local G, W, ns = T.load()
    local panel, text = { 0x19 / 255, 0x19 / 255, 0x19 / 255 }, { 0.974, 0.974, 0.974 }
    local r, g, b = ns.Color.Lift(panel, text, { 1, 0.49, 0.04 }, 4.5)
    T.color({ r, g, b }, "ff7d0a")
end)

T.it("Hex formats ffrrggbb", function()
    local G, W, ns = T.load()
    T.eq(ns.Color.Hex(1, 0.5, 0), "ffff8000")
end)
