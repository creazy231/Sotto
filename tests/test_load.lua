local T = T

local ALLOWED = {
    SottoDB = true, SLASH_SOTTO1 = true, SLASH_SOTTO2 = true,
    BINDING_HEADER_SOTTO = true, BINDING_NAME_SOTTO_TOGGLE = true, BINDING_NAME_SOTTO_REPLY = true,
    BINDING_NAME_SOTTO_NEXT = true,
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

T.it("the TOC targets WoW Forever and declares the saved variables", function()
    local text = io.open("Sotto.toc"):read("*a")
    T.ok(text:find("## Interface: 16001", 1, true), "interface 16001")
    T.ok(text:find("## SavedVariables: SottoDB", 1, true), "saved variables")
    T.ok(text:find("## OptionalDeps: EllesmereUI", 1, true), "optional EllesmereUI")
    T.ok(text:find("## Author: creazy231", 1, true), "public author name")
end)
