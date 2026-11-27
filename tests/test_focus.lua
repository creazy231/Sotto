local T = T

-- A click into the game world gives the keyboard back to the game (WIM's "Click to
-- Release Focus"): a short click on the world frame lets go of a box of Sotto's.

local function load(opts)
    local G, W, ns = T.load(opts)
    return G, W, ns, ns.UI
end

local function whisper(W, text, sender, o)
    W.chat("CHAT_MSG_WHISPER", W.whisperArgs(text, sender, o))
end

local function click(G, W, held, button)
    button = button or "LeftButton"
    W.mouseDown = W.mouseDown or {}
    W.mouseDown[button] = true
    G.WorldFrame:_fire("OnMouseDown", button)
    W.clock = W.clock + held
    G.WorldFrame:_fire("OnMouseUp", button) -- the client may still read it as down here
    W.mouseDown[button] = nil
end

T.it("a click into the game world gives the keyboard back, the draft stays", function()
    local G, W, ns, UI = load()
    whisper(W, "hey", "Aaa")
    UI.compose:Focus()
    UI.compose:SetText("on my way")
    click(G, W, 0.1)
    T.no(UI.compose:HasFocus(), "the box let go")
    T.eq(W.focus, nil, "nothing has the keyboard")
    T.eq(UI.compose.box:GetText(), "on my way", "the draft stays")
end)

T.it("a right-click into the world does it too, in combat as well", function()
    local G, W, ns, UI = load()
    whisper(W, "hey", "Aaa")
    W.combat = true
    UI.compose:Focus()
    click(G, W, 0.05, "RightButton")
    T.no(UI.compose:HasFocus())
end)

-- (On WoW Forever and Retail the game itself lets go of a box on any plain left
-- mouse-down outside it; this is the right button, which steers.)
T.it("holding the right button on the world to steer keeps the keyboard in the box", function()
    local G, W, ns, UI = load()
    whisper(W, "hey", "Aaa")
    UI.compose:Focus()
    click(G, W, 0.6, "RightButton")
    T.ok(UI.compose:HasFocus())
end)

T.it("tapping one button while the other is held down keeps the keyboard in the box", function()
    local G, W, ns, UI = load()
    whisper(W, "hey", "Aaa")
    UI.compose:Focus()
    W.mouseDown = { RightButton = true } -- steering
    click(G, W, 0.1, "LeftButton")
    T.ok(UI.compose:HasFocus())
end)

T.it("a world click lets go of the name field and of a separate window's box", function()
    local G, W, ns, UI = load()
    UI.NewConversation()
    T.eq(W.focus, UI.prompt.edit)
    click(G, W, 0.1)
    T.no(UI.prompt.edit:HasFocus(), "the name field let go")
    ns.Set("separate", true)
    whisper(W, "hey", "Bbb")
    local w = ns.Windows.For(ns.Store.Get("bbb"))
    w.pane.compose:Focus()
    click(G, W, 0.1)
    T.no(w.pane.compose:HasFocus(), "a separate window's box let go")
end)

T.it("a world click leaves other addons' boxes alone", function()
    local G, W, ns, UI = load()
    local other = G.CreateFrame("EditBox", nil, G.UIParent)
    other:SetFocus()
    click(G, W, 0.1)
    T.eq(W.focus, other)
end)
