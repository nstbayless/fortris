-- parse command line args
g_debug_mode = table.contains(arg, "debug") or table.contains(arg, "--debug")
g_test_mode = table.contains(arg, "test") or table.contains(arg, "--test") -- testing active

local function read_if_set(key, type)
  local idx = indexof(arg, key) or indexof(arg, "--" .. key)
  if idx ~= nil and idx < #arg then
    if type == nil or type == "string" then
      return arg[idx + 1]
    elseif type == "hex" then
      local success, v = pcall(tonumber, arg[idx + 1], 16)
      if success then
        assert(type(v) == "number")
        return v
      else
        assert(false, "invalid hex: " .. arg[idx + 1])
      end
    else
      assert(false, "unknown argument type: " .. type)
    end
  end
end

g_seed = read_if_set("seed", "hex")
g_load_demo = read_if_set("demo")
