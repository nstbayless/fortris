-- records and playbacks values

local DEMO = enum {
  "inactive",
  "recording",
  "playback"
}

g_demo = {
  state = DEMO.inactive,
  buffer = nil
}

local function buffer()
  assert(g_demo.buffer ~= nil and #g_demo.buffer > 0)
  if demo_is_recording() then
    return g_demo.buffer[#g_demo.buffer]
  elseif demo_is_playback() then
    if #g_demo.buffer >= g_demo.playback_idx then
      return g_demo.buffer[g_demo.playback_idx]
    else
      return {}
    end
  end
end

-- public expose of buffer()
function demo_get_buffer_entry()
  return buffer()
end

-- occurs on game begin
-- supply a playback buffer to playback instead of record.
function demo_init(playback)
  g_demo.state = tern(playback, DEMO.playback, DEMO.recording)
  g_demo.buffer = {{}}
  g_demo.playback_idx = 1
  g_demo.playback_complete = false

  -- begin playback if playback
  if playback then
    if type(playback) == "string" then
      demo_deserialize(playback)
    elseif type(playback) == "table" then
      g_demo.buffer = playback
      assert(#g_demo.buffer > 0 and type(g_demo.buffer[1]) == "table")
    else
      assert(false, "unrecognized type for playback: " .. type(playback))
    end
  end

  demo_setv("version", k_version)
  if demo_is_playback() then
    assert(demo_getv("version") == k_version, "demo has incorrect version number")
  end
end

-- advances to the next buffer (usually an update tick, but there is also one before the first update)
function demo_advance()
  if demo_is_recording() then
    assert(g_demo.buffer ~= nil)
    table.insert(g_demo.buffer, {})
  elseif demo_is_playback() then
    assert(g_demo.buffer ~= nil)
    g_demo.playback_idx = g_demo.playback_idx + 1
    if g_demo.playback_idx > #g_demo.buffer then
      g_demo.playback_complete = true
      g_demo.state = DEMO.inactive
      print("playback complete.")
    end
  end
end

function demo_is_playback()
  return g_demo.state == DEMO.playback
end

function demo_is_recording()
  return g_demo.state == DEMO.recording
end

function demo_getv(key)
  assert(demo_is_playback())
  return buffer()[key]
end

function demo_setv(key, v)
  if demo_is_recording() then
    buffer(key)[key] = v
  end
end

-- serializes demo to a string representing a delta-encoded list
function demo_serialize()
  local devs = {} -- delta-encoded values
  local state = {}
  for i, e in ipairs(g_demo.buffer) do
    local dev = {}
    for key, value in pairs(e) do
      -- delta encoding only
      if state[key] ~= value then
        dev[key] = value
        state[key] = value
      end
    end
    table.insert(devs, dev)
  end
  return serialize(devs)
end

-- serializes demo to a string representing a delta-encoded list
function demo_deserialize(s)
  local success, devs = deserialize(s)
  assert(success)
  assert(type(devs) == "table")
  print("demo length: " .. tostring(#devs) .. " entries")
  local state = {}
  assert(#g_demo.buffer <= 1, "cannot begin playback when demo recording in progress")
  g_demo.buffer = {}
  for i, dev in ipairs(devs) do
    assert(type(dev) == "table")
    local e = {}
    for key, value in pairs(dev) do
      state[key] = value
    end
    for key, value in pairs(state) do
      e[key] = value
    end
    table.insert(g_demo.buffer, e)
  end
  assert(#g_demo.buffer == #devs)
end

function demo_save()
  local s = demo_serialize()
  local fname = "save." .. os.date("%Y-%m-%d_%H%M%S") .. ".txt"
  print("saving to " .. love.filesystem.getSaveDirectory() .. "/" .. fname)
  fs_save(s, fname)
end