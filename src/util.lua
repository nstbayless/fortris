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

-- iterate over 2d array
-- for y, x, v in array_2d_iterate(a) do ... end
function array_2d_iterate(a)
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
    return y, x, v
  end, {a=a, x=1, y=1}, 0
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