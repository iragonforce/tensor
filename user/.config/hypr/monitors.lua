-- hyprmoncfg still produces monitors.conf. Read its data with Lua and apply native
-- monitor/workspace rules so saved profiles keep working after the Lua migration.
local path = os.getenv("HOME") .. "/.config/hypr/monitors.conf"
local file = assert(io.open(path, "r"))
local monitor
local function value(s)
    if s == "true" then return true end
    if s == "false" then return false end
    if s:match("^%-?%d+%.?%d*$") then return tonumber(s) end
    return s
end
for raw_line in file:lines() do
    local line = raw_line:match("^%s*(.-)%s*$")
    if line == "monitorv2 {" then
        monitor = {}
    elseif line == "}" and monitor then
        -- Keep the AMD-driven vertical panel on the stable SDR scanout path,
        -- including when hyprmoncfg regenerates or reloads a saved profile.
        if monitor.output == "DP-3" or (monitor.output and monitor.output:find("LG Ultra HD", 1, true)) then
            monitor.mode = "3840x2160@60"
            monitor.vrr = 0
            monitor.bitdepth = 8
            monitor.cm = "srgb"
        end
        hl.monitor(monitor)
        monitor = nil
    elseif line ~= "" and line:sub(1, 1) ~= "#" then
        local key, text = line:match("^(%S+)%s*=%s*(.-)%s*$")
        assert(key, "Invalid monitor profile line: " .. line)
        if monitor then
            monitor[key] = value(text)
        elseif key == "workspace" then
            local rule = {}
            for raw_part in text:gmatch("[^,]+") do
                local part = raw_part:match("^%s*(.-)%s*$")
                if not rule.workspace then
                    rule.workspace = part
                else
                    local k, v = part:match("^([^:]+):(.+)$")
                    assert(k, "Invalid workspace rule: " .. part)
                    rule[k] = value(v)
                end
            end
            hl.workspace_rule(rule)
        else
            error("Unsupported monitor profile directive: " .. key)
        end
    end
end
file:close()
assert(not monitor, "Unclosed monitor profile block")
