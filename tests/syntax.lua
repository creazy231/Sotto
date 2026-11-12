-- Compiles every Lua file of the addon (Lua 5.1 grammar via LuaJIT) and
-- checks that each file listed in the TOC exists.
-- Usage, from the addon folder: luajit tests/syntax.lua
local bad = 0
local p = io.popen('find Core UI tests -name "*.lua" 2>/dev/null')
for f in p:lines() do
    local chunk, err = loadfile(f)
    if not chunk then print("SYNTAX " .. err); bad = bad + 1 end
end
p:close()
for line in io.lines("Sotto.toc") do
    line = line:gsub("\r", "")
    if line ~= "" and not line:find("^#") then
        local path = line:gsub("\\", "/")
        local fh = io.open(path, "r")
        if fh then fh:close() else print("MISSING " .. path); bad = bad + 1 end
    end
end
print(bad == 0 and "syntax ok" or (bad .. " problem(s)"))
os.exit(bad == 0 and 0 or 1)
