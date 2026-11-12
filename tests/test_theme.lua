local T = T

local function rgb(c) return { c[1], c[2], c[3] } end

T.it("without EllesmereUI the palette matches the mockup tokens", function()
    local G, W, ns = T.load()
    local P = ns.Theme.P
    T.color(rgb(P.bg), "141414")
    T.color(rgb(P.panel), "191919")
    T.color(rgb(P.sidebar), "0e0e0e")
    T.color(rgb(P.panelAlt), "212121")
    T.color(rgb(P.sky), "2a2a2a")
    T.color(rgb(P.text), "f8f8f8")
    T.color(rgb(P.dim), "cacccf")
    T.color(rgb(P.muted), "a2a5a9")
    T.color(rgb(P.accent), "ff7d0a", "druid orange")
    T.near(P.bg[4], 0.92)
end)

T.it("with EllesmereUI the panel colour and font follow its skin", function()
    local G, W, ns = T.load({ eui = { panel = { 0.2, 0.1, 0.1, 0.8 }, font = "Interface\\AddOns\\X\\Foo.ttf" } })
    local P = ns.Theme.P
    T.near(P.bg[1], 0.2, 0.01)
    T.near(P.bg[4], 0.8)
    local path = ns.Theme.Font("body")
    T.eq(path, "Interface\\AddOns\\X\\Foo.ttf")
end)

T.it("accent 'eui' uses EllesmereUI's accent and follows live changes", function()
    local G, W, ns = T.load({ eui = { accent = { 0, 0.81, 1 } } })
    ns.Set("accent", "eui")
    T.color(rgb(ns.Theme.P.accent), "00cfff")
    local fired = 0
    ns.Listen("LOOKS_CHANGED", function() fired = fired + 1 end)
    W.euiChange({ accent = { 1, 0, 0 } })
    T.color(rgb(ns.Theme.P.accent), "ff0000")
    T.ok(fired >= 1, "LOOKS_CHANGED fired")
end)

T.it("accent 'eui' without EllesmereUI falls back to the class colour", function()
    local G, W, ns = T.load()
    ns.Set("accent", "eui")
    T.color(rgb(ns.Theme.P.accent), "ff7d0a")
end)

T.it("the class accent is lifted to read on the panel", function()
    local G, W, ns = T.load({ setup = function(G, W) W.player.classFile = "SHAMAN"; W.player.class = "Shaman" end })
    T.color(rgb(ns.Theme.P.accent), "2585e2")
end)

T.it("ClassColor lifts dark class colours", function()
    local G, W, ns = T.load()
    local r, g, b = ns.Theme.ClassColor("SHAMAN")
    T.color({ r, g, b }, "2585e2")
    r, g, b = ns.Theme.ClassColor("WARRIOR")
    T.color({ r, g, b }, "c79c6e")
end)

T.it("names use Expressway Bold when the EllesmereUI font is Expressway", function()
    local G, W, ns = T.load({ eui = { font = "Interface\\AddOns\\EllesmereUI\\media\\fonts\\Expressway.TTF" } })
    local path = ns.Theme.Font("bold")
    T.eq(path, "Interface\\AddOns\\EllesmereUI\\media\\fonts\\Expressway Bold.ttf")
end)

T.it("without EllesmereUI the game font is used", function()
    local G, W, ns = T.load()
    T.eq(ns.Theme.Font("body"), G.STANDARD_TEXT_FONT)
end)

T.it("font sizes follow the text size setting", function()
    local G, W, ns = T.load()
    local _, size = ns.Theme.Font("body")
    T.eq(size, 13)
    ns.Set("fontSize", 15)
    _, size = ns.Theme.Font("body")
    T.eq(size, 15)
    local _, meta = ns.Theme.Font("meta")
    T.eq(meta, 13)
end)

T.it("ApplyFont falls back to the regular font when the bold file is missing", function()
    local G, W, ns = T.load({ eui = { font = "Interface\\AddOns\\EllesmereUI\\media\\fonts\\Expressway.TTF" },
        setup = function(G, W) W.missingFonts = { ["Interface\\AddOns\\EllesmereUI\\media\\fonts\\Expressway Bold.ttf"] = true } end })
    local fs = G.UIParent:CreateFontString()
    ns.Theme.ApplyFont(fs, "bold")
    T.eq((fs:GetFont()), "Interface\\AddOns\\EllesmereUI\\media\\fonts\\Expressway.TTF")
end)
