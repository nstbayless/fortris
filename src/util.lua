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
function array_2d_iterate(a, base_idx)
  assert(a ~= nil)
  return function(state)
    local a = state.a
    if state.y > height2d(a) then
      return nil, nil, nil
    end
    local y = state.y
    local x = state.x
    local v = a[state.y][state.x]
    state.x = state.x + 1
    if state.x > width2d(a) then
      state.x = 1
      state.y = state.y + 1
    end
    return y - state.offset, x - state.offset, v
  end, {a=a, x=1, y=1, offset = -(base_idx or 1) + 1}, 0
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
  local a = {}
  for y = 1,h do
    a[y] = {}
    for x = 1,w do
      a[y][x] = v
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

math.tau = math.pi * 2