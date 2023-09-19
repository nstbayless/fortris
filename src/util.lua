local luatexts = require("ext.luatexts")

function table.clone(orig)
  local orig_type = type(orig)
  local copy
  if orig_type == 'table' then
      copy = {}
      for orig_key, orig_value in pairs(orig) do
          copy[orig_key] = orig_value
      end
  else -- number, string, boolean, etc
      copy = orig
  end
  return copy
end

-- returns true if a == b or all elements of a equal all elements of b
function table_equal(a, b)
  return is_subset(a, b) and is_subset(b, a)
end

-- returns true if a is a table-subset of b
-- this includes if a == b.
function is_subset(a, b)
  if a == b then
    return true
  end
  if type(b) ~= type({}) then
    return false
  end
  for key, value in pairs(a) do
    if b[key] ~= value then
      return false
    end
  end
  return true
end

-- returns table a but with table b's elements replacing the associated elements in a
function table_merge(a, b)
  t = table.clone(a)
  for key, value in pairs(b) do
    t[key] = value
  end
  return t
end

function array_2d_get_bbox(arr, base_idx)
  local miny = nil
  local minx = nil
  local maxy = nil
  local maxx = nil
  for y, x, v in array_2d_iterate(arr, base_idx) do
    if v ~= 0 then
      miny = math.min(y, miny)
      maxy = math.max(y, maxy)
      minx = math.min(x, minx)
      maxx = math.max(x, maxx)
    end
  end
  if minx then
    return minx, miny, maxx + 1, maxy + 1
  else
    return nil, nil, nil, nil
  end
end

-- grows out the nonzero region by one, and also pushes out bounds by one.
function array_2d_grow(arr, diagonals)
  local o = make_2d_array(width2d(arr) + 2, height2d(arr) + 2)
  for y, x, v in array_2d_iterate(arr) do
    if v ~= 0 then
      for ox = x,x+2 do
        local narrow_y = ibool(ox ~= x + 1 and diagonals)
        for oy = y + narrow_y,y+2 - narrow_y do
          if o[oy][ox] == 0 then
            o[oy][ox] =  v
          end
        end
      end
    end
  end

  return o
end

function rotate_2d_array_cw(arr)
  local a = {}
  local h = #arr
  for y, row in ipairs(arr) do
    for x, v in ipairs(row) do
      if y == 1 then
        a[x] = {}
      end
      a[x][h - y + 1] = v
    end
  end

  return a
end

function rotate_2d_array_ccw(arr)
  local a = {}
  for y, row in ipairs(arr) do
    local w = #row
    for x, v in ipairs(row) do
      if y == 1 then
        a[w - x + 1] = {}
      end
      a[w - x + 1][y] = v
    end
  end

  return a
end

function ordered_range(a, b, dx)
  dx = dx or 1
  assert(dx ~= 0, "cannot order by 0")
  a, b = math.floor(math.min(a, b)), math.floor(math.max(a, b))
  local state = {}
  if dx < 0 then
    state = {
      s = b,
      e = a,
      d = -1
    }
  else
    state = {
      s = a,
      e = b,
      d = 1
    }
  end
  return function(state, v)
    if v == "" then
      return state.s
    elseif v == state.e then
      return nil
    else
      return v + state.d
    end
  end, state, ""
end

-- iterate over entries in table
function entries(a)
  assert(type(a) == "table")
  return function(state)
    while true do
      state.idx = next(state.a, state.idx)
      if state.idx == nil then
        return nil
      elseif state.a[state.idx] ~= nil then
        return state.a[state.idx]
      end
    end
  end, {a = a, idx=nil}, 0
end

-- iterate over 2d array
-- for y, x, v in array_2d_iterate(a) do ... end
function array_2d_iterate(a, base_idx, dx, dy)
  assert(a ~= nil)
  if dx and dy then
    dx, dy = sign(dx), sign(dy)
    assert(dx ~= 0 and dy ~= 0)
  else
    dx = 1
    dy = 1
  end
  local xstart, ystart, xend, yend =
    tern(dx == 1, 1, width2d(a)),
    tern(dy == 1, 1, height2d(a)),
    tern(dx == -1, 0, width2d(a) + 1),
    tern(dy == -1, 0, height2d(a) + 1)
  return function(state)
    local a = state.a
    if state.y == state.yend then
      return nil, nil, nil
    end
    local y = state.y
    local x = state.x
    local v = a[state.y][state.x]
    state.x = state.x + state.dx
    if state.x == state.xend then
      state.x = state.xstart
      state.y = state.y + state.dy
    end
    return y - state.offset, x - state.offset, v
  end, {a=a, x=xstart, y=ystart, xstart=xstart, ystart=ystart, xend=xend, yend=yend, offset = -(base_idx or 1) + 1, dx = dx, dy = dy}, 0
end

-- ternary if
function tern(c, t, f)
  if c then
      return t
  else
      return f
  end
end

-- bool to int
function ibool(v)
  return tern(v, 1, 0)
end

-- default value, defaulting to a, then b, then c, if not nil...
function d(a, b, c)
  -- TODO: implement variadically...
  if a ~= nil then
    return a
  else
    if b ~= nil then
      return b
    else
      return c
    end
  end
end

function math.round(v)
  return math.floor(v + 0.5)
end

function math.clamp(x, a, b)
  return math.min(math.max(x, a), b)
end

function indexof(t, x)
  for i, v in ipairs(t) do
    if v == x then
      return i
    end
  end
  return nil
end

function table.contains(t, x)
  return not not indexof(t, x)
end

-- width and height of 2d arrays
function height2d(t)
  return #t
end

function width2d(t)
  return tern(
    #t <= 0,
    0, #(t[1])
  )
end

function dimensions2d(t)
  return width2d(t), height2d(t)
end

-- creates a [y][x]-indexed 2d array.
function make_2d_array(w, h, v)
  v = v or 0
  local a = {}
  for y = 1,h do
    a[y] = {}
    for x = 1,w do
      a[y][x] = v
    end
  end

  return a
end

-- creates a [y][x]-indexed 2d array containing a circle.
function make_2d_array_circle(w, h, v, v2)
  v = v or 1
  v2 = v2 or 0
  local a = {}
  for y = 1,h do
    a[y] = {}
    for x = 1,w do
      a[y][x] = tern(point_distance(w/2, h/2, x - 0.5, y - 0.5) <= math.min(w, h)/2, v, v2)
    end
  end

  return a
end

function hx(v, k)
  k = k or 2
  return string.format("%0" .. tostring(k) .. "x", v)
end

function HX(v, k)
  k = k or 2
  return string.format("%0" .. tostring(k) .. "X", v)
end

-- note -- this has a bug if any key or value contain commas (,) or equals (=).
function table.string_key(t)
  local s = ":"
  for k, v in pairs(t) do
    s = s .. tostring(k) .. "=" .. tostring(v) .. ":"
  end
  return s
end

function hex(v)
  return string.format("%x", v)
end

function HEX(v)
  return string.format("%X", v)
end

function in_range(y, a, b)
  return y >= a and y < b
end

-- returns s shrunk toward t by a
function shrink_toward(s, t, a)
  if math.abs(t - s) < a then
    return t
  else
    return s + tern(s < t, a, -a)
  end
end

function sign(x)
  return math.max(math.min(x * 1e200 * 1e200, 1), -1)
end

-- returns a version of the path where dx,dy between nodes is no greater than 1.
function densify_path(path)
  if not path then
    return nil
  end
  local a = {}
  local first = true
  for _, node in ipairs(path) do
    if first then
      table.insert(a, {x = node.x, y = node.y})
    else
      while a[#a].x ~= node.x or a[#a].y ~= node.y do
        assert(a[#a].x and a[#a].y and node.x and node.y)
        local nextx = a[#a].x + sign(node.x - a[#a].x)
        local nexty = a[#a].y + sign(node.y - a[#a].y)
        assert(nextx and nexty)
        table.insert(
          a, {
            x = nextx,
            y = nexty
          }
        )
      end
    end
    first = false
  end
  return a
end

-- from https://love2d.org/wiki/HSV_color
-- adapted for 0-1 coordinate space.
function hsv_to_rgb(h, s, v)
  h, s, v = math.clamp(h, 0, 1), math.clamp(s, 0, 1), math.clamp(v, 0, 1)
  if s <= 0 then return v,v,v end
  h = h * 6
  local c = v*s
  local x = (1-math.abs((h%2)-1))*c
  local m,r,g,b = (v-c), 0,0,0
  if h < 1     then r,g,b = c,x,0
  elseif h < 2 then r,g,b = x,c,0
  elseif h < 3 then r,g,b = 0,c,x
  elseif h < 4 then r,g,b = 0,x,c
  elseif h < 5 then r,g,b = x,0,c
  else              r,g,b = c,0,x
  end
  return (r+m),(g+m),(b+m)
end

function point_distance(x1, y1, x2, y2)
  local dx = (x2 - x1)
  local dy = (y2 - y1)
  return math.sqrt(dx * dx + dy * dy)
end

function math.frandom(a, b)
  if a == nil and b == nil then
    a = 0
    b = 1
  end
  if a == nil then
    a = 0
  end
  if b == nil then
    a, b = 0, a
  end

  return a + math.random() * (b - a)
end

function ilinweightrandom(a, b)
  local r = math.frandom()
  local p = r * r
  return math.round(p * b + (1 - p) * a)
end

math.tau = math.pi * 2

function shuffle(a)
  local shuffled = {}
  for i, v in ipairs(a) do
    local pos = math.random(1, #shuffled + 1)
    table.insert(shuffled, pos, v)
  end
  return shuffled
end

function shuffle_and_idxs(a)
  local shuffled = table.clone(a)
  local idxs = {}
  for i, v in ipairs(a) do
    local swapidx = math.random(i, #shuffled)
    table.swap(i, swapidx)
    idxs[v] = swapidx
  end
  return shuffled, idxs
end

function iota(x, y)
  if not y then
    x, y = 1, x
  end
  local a = {}
  for i = x,y do
    a[i] = i
  end
  return a
end

-- swaps indices i1, i2 of the array
function table.swap(a, i1, i2)
  a[i1], a[i2] = a[i2], a[i1]
end

-- gets index of first nonzero bit
-- returns 32 if all bits are clear.
function bit.blog(a)
  for i = 0,31 do
    if bit.band(a, bit.lshift(1, i)) ~= 0 then
      return i
    end
  end
  return 32
end

-- gets index of first zero bit
-- returns 32 if all bits are set.
function bit.nblog(a)
  for i = 0,31 do
    if bit.band(a, bit.lshift(1, i)) == 0 then
      return i
    end
  end
  return 32
end

function string.trim(s)
  return s:gsub("^%s*(.-)%s*$", "%1")
end

function lerp(x, a, b)
  return (1 - x) * a + x * b
end

-- https://stackoverflow.com/a/45365150
function disp_time(time)
  local floor = math.floor
  local days = floor(time/86400)
  local remaining = time % 86400
  local hours = floor(remaining/3600)
  local hours_s, days_s, minutes_s, seconds_s
  remaining = remaining % 3600
  local minutes = floor(remaining/60)
  remaining = remaining % 60
  local seconds = remaining
  if (hours < 10) then
    hours_s = "0" .. tostring(hours)
  else
    hours_s = tostring(hours)
  end
  if (minutes < 10) then
    minutes_s = "0" .. tostring(minutes)
  else
    minutes_s = tostring(minutes)
  end
  if (seconds < 10) then
    seconds_s = "0" .. tostring(seconds)
  else
    seconds_s = tostring(seconds)
  end
  local answer = tern(days > 0, tostring(days)..':', "")..tern(hours > 0, hours_s..':', '')..minutes_s..':'..seconds_s
  return answer
end

function poisson(t, r)
  local lambda = tern(r, r * t, t)
  assert(lambda)
  local x = math.frandom() -- sampler
  local maxcalc = 1000
  local p = math.exp(-lambda)
  assert(p > 0)
  for k = 0,maxcalc do
    -- probability p(k)
    if x <= p then
      return k
    else
      x = x - p
      p = p * lambda / math.max(k, 1)
    end
  end
  return maxcalc + 1
end

-- http://www.unendli.ch/posts/2016-07-22-enumerations-in-lua.html
function enum(tbl)
  for i, v in pairs(tbl) do
    tbl[v] = i
  end
  
  return tbl
end

-- serializes a value to a string
function serialize(value)
  local s = luatexts.save(value)
  assert(type(s) == "string")
  return s
end

-- returns value from string
function deserialize(s)
  assert(type(s) == "string")
  return luatexts.load(s)
end