local function rindex(tl, t, tr, l, c, r, bl, b, br, v)
  return tl + 2 * t + 4 * tr + 8 * l + 0x10 * c + 0x20 * r + 0x40 * bl + 0x80 * b + 0x100 * br + 0x200 * v
end

local g_util_idx = {}

function set_s_array(arr)
  g_util_idx = arr
end

local function s(value, ...)
  local a = {...}
  assert(#a == 10)
  for i, v in ipairs(a) do
    if v == false then
      a[i] = 0
      s(value, unpack(a))
      a[i] = 1
      s(value, unpack(a))
      return
    end
  end
  g_util_idx[rindex(...)] = value
end

local function sr(a0, a1, a2, a3, tl, t, tr, l, c, r, bl, b, br, v)
  local a = {a0, a1, a2, a3}
  for i = 1,4 do
    s(a[i], tl, t, tr, l, c, r, bl, b, br, v)

    -- rotate
    tl, t, tr, r, br, b, bl, l = bl, l, tl, t, tr, r, br, b
  end
end

return {s=s, sr=sr, set_s_array=set_s_array}