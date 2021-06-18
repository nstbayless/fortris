-- parse command line args
g_debug_mode = table.contains(arg, "debug") or table.contains(arg, "--debug")
g_test_mode = table.contains(arg, "test") or table.contains(arg, "--test") -- testing active

g_seed = nil
local seed_idx = indexof(arg, "seed") or indexof(arg, "--seed")
if seed_idx ~= nil then
  local success, seed = pcall(tonumber, arg[seed_idx + 1], 16)
  if success then
    assert(type(seed) == "number")
    g_seed = seed
  else
    print(seed)
  end
end
if g_seed ~= nil then
  assert(type(g_seed) == "number")
end