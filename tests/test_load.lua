local T = T

local ALLOWED = {
    SottoDB = true, SLASH_SOTTO1 = true, SLASH_SOTTO2 = true,
    BINDING_HEADER_SOTTO = true, BINDING_NAME_SOTTO_TOGGLE = true, BINDING_NAME_SOTTO_REPLY = true,
    BINDING_NAME_SOTTO_NEXT = true, BINDING_NAME_SOTTO_REPLY_SENT = true, Sotto_BindingReplySent = true,
    Sotto_OnAddonCompartmentClick = true, Sotto_OnAddonCompartmentEnter = true, Sotto_OnAddonCompartmentLeave = true,
    Sotto_BindingToggle = true, Sotto_BindingReply = true, Sotto_BindingNext = true,
}

T.it("every TOC file loads without error", function()
    local G, W, ns = T.load()
    T.ok(ns.L, "ns.L exists")
    T.ok(#T.tocFiles() >= 3, "TOC lists the core files")
end)

T.it("only the allowed globals are created", function()
    local G, W = T.load()
    for k in pairs(W.globalsWritten) do
        if not ALLOWED[k] then error("unexpected global: " .. tostring(k)) end
    end
end)

-- One TOC for every client (warcraft.wiki.gg/wiki/TOC_format, 2026-11-13): Retail 12.1.5
-- and its 12.1.7 test realm, MoP Classic, Cataclysm, Titan-Reforged, Wrath, TBC
-- Anniversary, WoW Forever, Classic Era. Retail loads only an exact match.
local INTERFACES = { "120105", "120107", "50504", "40402", "38002", "30405", "20506", "16001", "11509" }

T.it("the TOC loads on Retail, every Classic client and WoW Forever", function()
    local text = io.open("Sotto.toc"):read("*a")
    local line = text:match("## Interface:%s*([^\r\n]+)")
    T.ok(line, "an Interface line")
    local listed = {}
    for v in line:gmatch("%d+") do listed[v] = true end
    for _, v in ipairs(INTERFACES) do T.ok(listed[v], "interface " .. v) end
end)

T.it("the TOC declares the saved variables and the author", function()
    local text = io.open("Sotto.toc"):read("*a")
    T.ok(text:find("## SavedVariables: SottoDB", 1, true), "saved variables")
    T.ok(text:find("## OptionalDeps: EllesmereUI", 1, true), "optional EllesmereUI")
    T.ok(text:find("## Author: creazy231", 1, true), "public author name")
end)
