-------------------------------------------------------------------------------
--  Sotto -- test harness: assertions and the addon loader.
--  Run everything with `luajit tests/run.lua` from the addon folder.
-------------------------------------------------------------------------------
local F = dofile("tests/fake_wow.lua")

local T = {}
local results = { pass = 0, fail = 0, failures = {} }
local current = "?"

local function fmt(v)
    if type(v) == "string" then return string.format("%q", v) end
    if type(v) == "table" then
        local parts = {}
        for i = 1, #v do parts[#parts + 1] = fmt(v[i]) end
        if #parts > 0 then return "{" .. table.concat(parts, ", ") .. "}" end
    end
    return tostring(v)
end
T.fmt = fmt

function T.file(name) current = name end

function T.it(name, fn)
    local ok, err = xpcall(fn, debug.traceback)
    if ok then
        results.pass = results.pass + 1
    else
        results.fail = results.fail + 1
        results.failures[#results.failures + 1] = current .. " :: " .. name .. "\n    " .. tostring(err)
    end
end

function T.eq(actual, expected, msg)
    if actual ~= expected then
        error((msg or "eq") .. ": expected " .. fmt(expected) .. ", got " .. fmt(actual), 2)
    end
end

function T.ok(v, msg) if not v then error(msg or "expected a truthy value", 2) end end
function T.no(v, msg) if v then error((msg or "expected a falsy value") .. ", got " .. fmt(v), 2) end end

function T.near(a, b, eps, msg)
    eps = eps or 1e-3
    if type(a) ~= "number" or type(b) ~= "number" or math.abs(a - b) > eps then
        error((msg or "near") .. ": expected ~" .. fmt(b) .. ", got " .. fmt(a), 2)
    end
end

function T.color(c, hex, msg, eps)
    local r = tonumber(hex:sub(1, 2), 16) / 255
    local g = tonumber(hex:sub(3, 4), 16) / 255
    local b = tonumber(hex:sub(5, 6), 16) / 255
    eps = eps or 1.5 / 255
    if type(c) ~= "table" or math.abs(c[1] - r) > eps or math.abs(c[2] - g) > eps or math.abs(c[3] - b) > eps then
        local got = type(c) == "table" and string.format("%02x%02x%02x", c[1] * 255 + 0.5, c[2] * 255 + 0.5, c[3] * 255 + 0.5) or fmt(c)
        error((msg or "color") .. ": expected #" .. hex .. ", got #" .. got, 2)
    end
end

function T.has(list, value, msg)
    for _, v in ipairs(list) do if v == value then return end end
    error((msg or "has") .. ": " .. fmt(value) .. " not in " .. fmt(list), 2)
end

function T.raises(fn, pattern, msg)
    local ok, err = pcall(fn)
    if ok then error((msg or "raises") .. ": no error", 2) end
    if pattern and not tostring(err):find(pattern) then
        error((msg or "raises") .. ": error " .. fmt(tostring(err)) .. " does not match " .. pattern, 2)
    end
end

function T.report()
    for _, f in ipairs(results.failures) do print("FAIL " .. f) end
    print(string.format("%d passed, %d failed", results.pass, results.fail))
    return results.fail == 0
end

-------------------------------------------------------------------------------
--  Loader
-------------------------------------------------------------------------------
function T.tocFiles()
    local files = {}
    for line in io.lines("Sotto.toc") do
        line = line:gsub("\r", "")
        if line ~= "" and not line:find("^#") then files[#files + 1] = (line:gsub("\\", "/")) end
    end
    return files
end

T.secret = F.secret

-- Fresh fake client + Sotto loaded into it. opts.only = list of files to load
-- (default: the TOC), opts.eui = EllesmereUI options (installs the stand-in),
-- opts.db = existing SottoDB, opts.login = false to stop before PLAYER_LOGIN.
function T.load(opts)
    opts = opts or {}
    local G, W = F.new(opts)
    if opts.eui then W.installEUI(opts.eui == true and {} or opts.eui) end
    if opts.setup then opts.setup(G, W) end
    local ns = {}
    for _, path in ipairs(opts.only or T.tocFiles()) do
        if path:find("%.lua$") then
            local chunk, err = loadfile(path)
            if not chunk then error("load " .. path .. ": " .. tostring(err)) end
            setfenv(chunk, G)
            chunk("Sotto", ns)
        end
    end
    rawset(G, "SottoDB", opts.db)
    W.fire("ADDON_LOADED", "Sotto")
    if opts.login ~= false then
        W.fire("PLAYER_LOGIN")
        W.euiLogin()
        W.fire("PLAYER_ENTERING_WORLD", true, false)
        W.advance(0)
    end
    return G, W, ns
end

return T
