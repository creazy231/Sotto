-- Runs every tests/test_*.lua (or the files named on the command line).
-- Usage, from the addon folder: luajit tests/run.lua [tests/test_x.lua ...]
package.path = "./?.lua;" .. package.path
local T = dofile("tests/harness.lua")
_G.T = T

local files = { ... }
if #files == 0 then
    local p = io.popen('ls tests/test_*.lua 2>/dev/null')
    for f in p:lines() do files[#files + 1] = f end
    p:close()
end
for _, f in ipairs(files) do
    T.file(f:match("([^/]+)%.lua$"))
    local chunk, err = loadfile(f)
    if not chunk then
        print("FAIL " .. f .. " does not compile: " .. tostring(err))
        os.exit(1)
    end
    chunk()
end
os.exit(T.report() and 0 or 1)
